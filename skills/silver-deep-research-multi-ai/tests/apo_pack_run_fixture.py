"""Test fixture: run a test inside exactly the context a real APO category-pack run installs.

There is no vendor catalogue anywhere in the product (R12-02): the vendors of a run are the pack's
names plus whatever the workers named. A test that needs the APO vocabulary and vendor set uses
``@with_apo_pack_run``, which installs what production installs for a run whose need profile selects
the pack -- the pack's vocabulary (``pack_vocabulary.activated``), ``_effective_known_solutions(need)``,
the resolved pack and its overview seeds (through the same ``run_context`` the parsers use) -- and nothing else (no module-level lists are patched).
"""

from __future__ import annotations

import functools

PACK_ID = "agentic-sdlc-process-orchestrator"
NEED = {"category_pack_id": PACK_ID}


def with_apo_pack_run(cls):
    """Class decorator: run every test method in an APO pack run context."""
    import materialize_solution_artifacts as mat
    import pack_vocabulary
    from category_pack import resolve_pack_from_need

    pack = resolve_pack_from_need(NEED)
    known = mat._effective_known_solutions(NEED)

    def in_pack_run(test):
        @functools.wraps(test)
        def run(*args, **kwargs):
            with pack_vocabulary.activated(pack), mat.run_context(known, pack):
                return test(*args, **kwargs)

        return run

    for name, value in list(vars(cls).items()):
        if name.startswith("test") and callable(value):
            setattr(cls, name, in_pack_run(value))
    return cls


def plain_vendor_spellings(cls):
    """Class decorator: every spelling of a vendor counts in prose, as if no vendor name were an ordinary word.

    For tests of classification, packaging or parsing structure that write the pack's vendors as bare names in
    their claims. What an ambiguous vendor needs in order to be credited is pinned by
    test_vendor_identity_generative and test_vendor_mention_corpus.
    """
    from unittest import mock

    import vendor_identity

    def plain(test):
        @functools.wraps(test)
        def run(*args, **kwargs):
            import materialize_solution_artifacts as mat

            mat._EXTRACTED.clear()  # the memo does not know the patch: results from outside it must not leak in or out
            try:
                with mock.patch.object(vendor_identity.Registry, "is_prose_spelling", lambda self, spelling: True):
                    return test(*args, **kwargs)
            finally:
                mat._EXTRACTED.clear()

        return run

    for name, value in list(vars(cls).items()):
        if name.startswith("test") and callable(value):
            setattr(cls, name, plain(value))
    return cls


def with_apo_pack_run_plain_names(cls):
    """``with_apo_pack_run`` with every spelling of a vendor counting in prose (see ``plain_vendor_spellings``)."""
    return with_apo_pack_run(plain_vendor_spellings(cls))
