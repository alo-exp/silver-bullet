"""Which commit does a release-creating command release? Read from the command exactly as gh reads it.

``release_scope(result, mcp_tool, fields, origin_slug, environ, command)`` returns
``{"ok": bool, "reason": str, "tag": str, "target": str}``. ``ok`` is false (and ``reason`` says why) whenever the
tag/target cannot be read with certainty: more than one release in the command, a tool other than
``gh release create``, ``gh api .../releases`` and the MCP ``create_release``, a flag the parser does not know, a
repeated or computed value, another repository than the checkout's. The deploy tier resolves the commit with git and
blocks (``cannot determine release commit``) when ``ok`` is false. Design: DESIGN-G1-push-classifier.md section 5.
"""

from __future__ import annotations

import os
import re

BOOL, VALUE, MULTI = "bool", "value", "multi"
GH_RELEASE_CREATE = {
    "-d": ("--draft", BOOL), "--draft": ("--draft", BOOL),
    "-p": ("--prerelease", BOOL), "--prerelease": ("--prerelease", BOOL),
    "--generate-notes": ("--generate-notes", BOOL), "--verify-tag": ("--verify-tag", BOOL),
    "--notes-from-tag": ("--notes-from-tag", BOOL), "--latest": ("--latest", BOOL),
    "--fail-on-no-commits": ("--fail-on-no-commits", BOOL),
    "-t": ("--title", VALUE), "--title": ("--title", VALUE), "-n": ("--notes", VALUE), "--notes": ("--notes", VALUE),
    "-F": ("--notes-file", VALUE), "--notes-file": ("--notes-file", VALUE), "--target": ("--target", VALUE),
    "--discussion-category": ("--discussion-category", VALUE), "--notes-start-tag": ("--notes-start-tag", VALUE),
    "-R": ("--repo", VALUE), "--repo": ("--repo", VALUE),
}
GH_API = {
    "-i": ("--include", BOOL), "--include": ("--include", BOOL), "--paginate": ("--paginate", BOOL),
    "--silent": ("--silent", BOOL), "--slurp": ("--slurp", BOOL), "--verbose": ("--verbose", BOOL),
    "-X": ("--method", VALUE), "--method": ("--method", VALUE), "-q": ("--jq", VALUE), "--jq": ("--jq", VALUE),
    "-t": ("--template", VALUE), "--template": ("--template", VALUE), "--hostname": ("--hostname", VALUE),
    "--cache": ("--cache", VALUE), "-p": ("--preview", VALUE), "--preview": ("--preview", VALUE),
    "--input": ("--input", VALUE),
    "-H": ("--header", MULTI), "--header": ("--header", MULTI),
    "-f": ("--raw-field", MULTI), "--raw-field": ("--raw-field", MULTI),
    "-F": ("--field", MULTI), "--field": ("--field", MULTI),
}
BOOL_WORDS = {"1", "t", "T", "TRUE", "true", "True", "0", "f", "F", "FALSE", "false", "False"}
PLACEHOLDERS = {"{owner}", "{repo}", ":owner", ":repo"}
ENDPOINT_RE = re.compile(r"^repos/([^/]+)/([^/]+)/releases/?$")
SLUG_PART = re.compile(r"^[A-Za-z0-9._-]+$")
MCP_SHAPE = "Silver Bullet reads the release commit only from gh release create, gh api .../releases or the GitHub MCP create_release"


class Deny(Exception):
    """The release commit cannot be read; the message is the one-sentence reason."""


def parse_pflags(args, spec):
    """pflag/cobra parsing of ``args`` -> ({canonical flag: [values]}, [positionals]); Deny on anything unusual.

    Forms: ``--name=value``, ``--name value``, ``--bool``, ``--bool=false``, shorthand clusters ``-abc`` (a value
    letter takes the rest of the cluster, with an optional leading ``=``, else the next word), flags and
    positionals interleaved, ``--`` ends the flags, no prefix abbreviations, a non-repeatable value flag given
    twice is denied."""
    flags, positionals, i = {}, [], 0

    def take(name, kind, value):
        if kind == BOOL:
            if value is not None and value not in BOOL_WORDS:
                raise Deny("the value %r of %s is not a boolean" % (value, name))
            value = "true" if value in (None, "1", "t", "T", "TRUE", "true", "True") else "false"
        elif name in flags and kind == VALUE:
            raise Deny("%s is given twice" % name)
        flags.setdefault(name, []).append(value)

    while i < len(args):
        word = args[i]
        i += 1
        if word == "--":
            positionals += args[i:]
            break
        if word.startswith("--"):
            name, eq, value = word.partition("=")
            if name not in spec:
                raise Deny("the flag %s is not one Silver Bullet reads" % name)
            canon, kind = spec[name]
            if kind != BOOL and not eq:
                if i >= len(args):
                    raise Deny("the flag %s has no value" % name)
                value, i = args[i], i + 1
            take(canon, kind, value if (eq or kind != BOOL) else None)
        elif word.startswith("-") and len(word) > 1:
            j = 1
            while j < len(word):
                letter = "-" + word[j]
                if letter not in spec:
                    raise Deny("the flag %s is not one Silver Bullet reads" % letter)
                canon, kind = spec[letter]
                rest = word[j + 1:]
                if kind == BOOL:
                    if rest.startswith("="):
                        take(canon, kind, rest[1:])
                        break
                    take(canon, kind, None)
                    j += 1
                    continue
                if rest.startswith("="):
                    rest = rest[1:]
                if not rest:
                    if i >= len(args):
                        raise Deny("the flag %s has no value" % letter)
                    rest, i = args[i], i + 1
                take(canon, kind, rest)
                break
        else:
            positionals.append(word)
    return flags, positionals


def computed(value):
    return "$" in value or "`" in value


def parse_fields(flags):
    """gh api -f/-F fields -> {key: value} for tag_name and target_commitish; Deny on anything unreadable."""
    found = {}
    for flag in ("--raw-field", "--field"):
        for raw in flags.get(flag, []):
            key, eq, value = raw.partition("=")
            if not eq:
                raise Deny("the field %r has no value" % raw)
            if key.startswith(("tag_name[", "target_commitish[")):
                raise Deny("the field %s is an array or object form" % key)
            if flag == "--field" and (value.startswith("@") or "{" in value):
                raise Deny("the -F field %s is read from a file or expanded by gh" % key)
            if computed(value):
                raise Deny("the field %s is computed at run time" % key)
            if key in ("tag_name", "target_commitish"):
                if key in found:
                    raise Deny("%s is given more than once" % key)
                found[key] = value
    return found


def endpoint_slug(endpoint):
    """``repos/O/R/releases`` (also with a leading slash or the api.github.com prefix) -> "O/R"; Deny otherwise."""
    for prefix in ("https://api.github.com/", "/"):
        if endpoint.startswith(prefix):
            endpoint = endpoint[len(prefix):]
    match = ENDPOINT_RE.match(endpoint)
    if match is None:
        raise Deny("the endpoint %r is not repos/<owner>/<repo>/releases" % endpoint)
    return "%s/%s" % (match.group(1), match.group(2))


def check_repository(slug, origin_slug, environ, command):
    """The release must be in the repository of this checkout: {owner}/{repo} or the slug of remote.origin.url."""
    parts = slug.split("/")
    if len(parts) != 2 or not all(part in PLACEHOLDERS or SLUG_PART.match(part) for part in parts):
        raise Deny("the repository %r is not an owner/repo" % slug)
    if not all(part in PLACEHOLDERS for part in parts):
        if any(part in PLACEHOLDERS for part in parts) or origin_slug is None or slug.lower() != origin_slug.lower():
            raise Deny("the release is in another repository; its commit cannot be read from this checkout")
    gh_repo = environ.get("GH_REPO")
    if gh_repo and (origin_slug is None or gh_repo.lower() != origin_slug.lower()):
        raise Deny("GH_REPO redirects the release to another repository")
    if "GH_REPO" in command or "GH_HOST" in command:
        raise Deny("GH_REPO/GH_HOST in the command redirect the release to another repository or host")


def release_scope(result, mcp_tool, fields, origin_slug, environ, command=""):
    try:
        return _release_scope(result, mcp_tool, fields, origin_slug, environ, command)
    except Deny as exc:
        return {"ok": False, "reason": str(exc), "tag": "", "target": ""}


def _release_scope(result, mcp_tool, fields, origin_slug, environ, command):
    entries = [d for d in result.get("delivery") or [] if d.get("action") == "release_create"]
    if len(entries) != 1:
        raise Deny("cannot determine release commit: this command creates %d releases; create one release per "
                   "command" % len(entries))
    entry = entries[0]
    if entry.get("possible"):
        raise Deny(MCP_SHAPE)
    argv = entry.get("argv")
    if argv is None:
        tag, target = mcp_release(mcp_tool, fields, origin_slug, environ, command)
    else:
        tag, target = shell_release(argv, origin_slug, environ, command)
    for value in (tag, target):
        if computed(value):
            raise Deny("the tag or target is computed at run time")
    return {"ok": True, "reason": "", "tag": tag, "target": target}


def mcp_release(mcp_tool, fields, origin_slug, environ, command):
    if mcp_tool != "create_release":
        raise Deny(MCP_SHAPE)
    owner, repo = fields.get("owner"), fields.get("repo")
    if not (isinstance(owner, str) and isinstance(repo, str)):
        raise Deny("the release repository is not named by owner and repo")
    check_repository("%s/%s" % (owner, repo), origin_slug, environ, command)
    tag = fields.get("tag_name", fields.get("tag", ""))
    target = fields.get("target_commitish", fields.get("target", ""))
    if not (isinstance(tag, str) and isinstance(target, str)):
        raise Deny("the tag or target is not text")
    return tag, target


def shell_release(argv, origin_slug, environ, command):
    if os.path.basename(argv[0]) != "gh":
        raise Deny(MCP_SHAPE)
    words = argv[1:]
    if words[:1] == ["release"] and words[1:2] in (["create"], ["new"]):
        flags, positionals = parse_pflags(words[2:], GH_RELEASE_CREATE)
        if not positionals:
            raise Deny("the release has no tag")
        if flags.get("--repo"):
            check_repository(flags["--repo"][0], origin_slug, environ, command)
        else:
            check_repository("{owner}/{repo}", origin_slug, environ, command)
        return positionals[0], (flags.get("--target") or [""])[0]
    if words[:1] == ["api"]:
        flags, positionals = parse_pflags(words[1:], GH_API)
        if len(positionals) != 1:
            raise Deny("gh api needs exactly one endpoint")
        if "--input" in flags or "--hostname" in flags:
            raise Deny("the release body is read from --input or sent to another host")
        method = (flags.get("--method") or ["POST"])[0].upper()
        if method != "POST":
            raise Deny("the method %s does not create a release" % method)
        check_repository(endpoint_slug(positionals[0]), origin_slug, environ, command)
        found = parse_fields(flags)
        return found.get("tag_name", ""), found.get("target_commitish", "")
    raise Deny(MCP_SHAPE)
