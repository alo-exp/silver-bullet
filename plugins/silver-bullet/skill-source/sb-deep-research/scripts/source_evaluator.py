#!/usr/bin/env python3
"""
Source Credibility Evaluator
Assesses source quality with NATO Admiralty-style grading (idea-derived; see reference/source-grading.md).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from urllib.parse import urlparse


RELIABILITY_LETTERS = "ABCDEF"
CREDIBILITY_DIGITS = "123456"


@dataclass
class CredibilityScore:
    """Represents source credibility assessment"""
    overall_score: float  # 0-100
    domain_authority: float  # 0-100
    recency: float  # 0-100
    expertise: float  # 0-100
    bias_score: float  # 0-100 (higher = more neutral)
    reliability_code: str  # Admiralty e.g. A1, B2
    authority_tier: str  # primary, secondary, tertiary, unknown
    source_class: str  # primary, secondary, tertiary, portal, unknown
    bias_flags: List[str] = field(default_factory=list)
    factors: Dict[str, str] = field(default_factory=dict)
    recommendation: str = "verify"  # high_trust, moderate_trust, low_trust, verify


class SourceEvaluator:
    """Evaluates source credibility and Admiralty-style grades"""

    HIGH_AUTHORITY_DOMAINS = {
        'arxiv.org', 'nature.com', 'science.org', 'cell.com', 'nejm.org',
        'thelancet.com', 'springer.com', 'sciencedirect.com', 'plos.org',
        'ieee.org', 'acm.org', 'pubmed.ncbi.nlm.nih.gov',
        'nih.gov', 'cdc.gov', 'who.int', 'fda.gov', 'nasa.gov',
        'gov.uk', 'europa.eu', 'un.org',
        'docs.python.org', 'developer.mozilla.org', 'docs.microsoft.com',
        'cloud.google.com', 'aws.amazon.com', 'kubernetes.io',
        'reuters.com', 'apnews.com', 'bbc.com', 'economist.com',
        'scientificamerican.com',
    }

    MODERATE_AUTHORITY_DOMAINS = {
        'techcrunch.com', 'theverge.com', 'arstechnica.com', 'wired.com',
        'zdnet.com', 'cnet.com', 'forbes.com', 'bloomberg.com', 'wsj.com', 'ft.com',
        'wikipedia.org', 'britannica.com', 'khanacademy.org',
        'medium.com', 'dev.to', 'stackoverflow.com', 'github.com',
    }

    LOW_AUTHORITY_INDICATORS = [
        'blogspot.com', 'wordpress.com', 'wix.com', 'substack.com',
    ]

    SENSATIONAL_PATTERNS = [
        '!', 'shocking', 'unbelievable', "you won't believe",
        'secret', "they don't want you to know", 'breaking:',
    ]

    def evaluate_source(
        self,
        url: str,
        title: str,
        content: Optional[str] = None,
        publication_date: Optional[str] = None,
        author: Optional[str] = None,
        source_type: Optional[str] = None,
    ) -> CredibilityScore:
        domain = self._extract_domain(url)
        subdomain_score = self._subdomain_authority_score(domain)

        domain_score = self._evaluate_domain_authority(domain)
        recency_score = self._evaluate_recency(publication_date)
        expertise_score = self._evaluate_expertise(domain, title, author)
        bias_score, bias_flags = self._evaluate_bias(domain, title, content)

        overall = (
            domain_score * 0.35
            + recency_score * 0.20
            + expertise_score * 0.25
            + bias_score * 0.20
            + subdomain_score * 0.05
        )

        authority_tier = self._authority_tier(domain, domain_score)
        source_class = self._source_class(source_type, authority_tier)
        reliability_letter = self._reliability_letter(domain_score, bias_score, bias_flags)
        credibility_digit = self._credibility_digit(recency_score, overall)
        reliability_code = f"{reliability_letter}{credibility_digit}"

        factors = self._identify_factors(
            domain, domain_score, recency_score, expertise_score, bias_score, bias_flags,
        )
        recommendation = self._generate_recommendation(overall, reliability_code)

        return CredibilityScore(
            overall_score=round(overall, 2),
            domain_authority=round(domain_score, 2),
            recency=round(recency_score, 2),
            expertise=round(expertise_score, 2),
            bias_score=round(bias_score, 2),
            reliability_code=reliability_code,
            authority_tier=authority_tier,
            source_class=source_class,
            bias_flags=bias_flags,
            factors=factors,
            recommendation=recommendation,
        )

    def _extract_domain(self, url: str) -> str:
        parsed = urlparse(url)
        domain = (parsed.netloc or '').lower().replace('www.', '')
        return domain

    def _subdomain_authority_score(self, domain: str) -> float:
        """Score subdomain patterns (docs.*, api.*, etc.)."""
        if domain.startswith('docs.') or domain.startswith('developer.'):
            return 90.0
        if '.gov' in domain or domain.endswith('.edu'):
            return 85.0
        if domain.count('.') >= 3:
            return 45.0
        return 60.0

    def _evaluate_domain_authority(self, domain: str) -> float:
        if domain in self.HIGH_AUTHORITY_DOMAINS:
            return 90.0
        if domain in self.MODERATE_AUTHORITY_DOMAINS:
            return 70.0
        if any(indicator in domain for indicator in self.LOW_AUTHORITY_INDICATORS):
            return 40.0
        if '.gov' in domain or domain.endswith('.edu'):
            return 88.0
        return 55.0

    def _evaluate_recency(self, publication_date: Optional[str]) -> float:
        if not publication_date:
            return 50.0
        try:
            pub_date = datetime.fromisoformat(publication_date.replace('Z', '+00:00'))
            age = datetime.now(pub_date.tzinfo) - pub_date if pub_date.tzinfo else datetime.now() - pub_date
            if age < timedelta(days=90):
                return 100.0
            if age < timedelta(days=365):
                return 85.0
            if age < timedelta(days=730):
                return 70.0
            if age < timedelta(days=1825):
                return 50.0
            return 30.0
        except Exception:
            return 50.0

    def _evaluate_expertise(self, domain: str, title: str, author: Optional[str]) -> float:
        score = 50.0
        if any(d in domain for d in ['arxiv', 'nature', 'science', 'ieee', 'acm']):
            score += 30
        if '.gov' in domain or 'who.int' in domain:
            score += 25
        if 'docs.' in domain or 'documentation' in title.lower():
            score += 20
        if author and any(t in author.lower() for t in ['dr.', 'phd', 'professor']):
            score += 15
        return min(score, 100.0)

    def _evaluate_bias(
        self, domain: str, title: str, content: Optional[str],
    ) -> tuple[float, List[str]]:
        score = 70.0
        flags: List[str] = []
        title_lower = title.lower()

        if any(indicator in title_lower for indicator in self.SENSATIONAL_PATTERNS):
            score -= 20
            flags.append('sensationalism')

        if any(d in domain for d in ['arxiv', 'nature', 'science', 'ieee']):
            score += 20

        if any(v in domain for v in ['aws.amazon', 'cloud.google', 'azure.microsoft']):
            flags.append('commercial')

        if content:
            balanced = ['however', 'although', 'on the other hand', 'critics argue']
            if any(indicator in content.lower() for indicator in balanced):
                score += 10

        return min(max(score, 0), 100.0), flags

    def _authority_tier(self, domain: str, domain_score: float) -> str:
        if domain_score >= 85 or '.gov' in domain or domain.endswith('.edu'):
            return 'primary'
        if domain_score >= 65:
            return 'secondary'
        if domain_score >= 45:
            return 'tertiary'
        return 'unknown'

    def _source_class(self, source_type: Optional[str], authority_tier: str) -> str:
        if source_type in ('government', 'academic', 'documentation'):
            return 'primary'
        if source_type == 'news':
            return 'secondary'
        if source_type == 'web':
            return authority_tier if authority_tier != 'unknown' else 'tertiary'
        return authority_tier if authority_tier != 'unknown' else 'unknown'

    def _reliability_letter(self, domain_score: float, bias_score: float, flags: List[str]) -> str:
        if 'sensationalism' in flags and domain_score < 50:
            return 'E'
        if domain_score >= 88 and bias_score >= 75:
            return 'A'
        if domain_score >= 75:
            return 'B'
        if domain_score >= 55:
            return 'C'
        if domain_score >= 40:
            return 'D'
        if domain_score < 30:
            return 'E'
        return 'F'

    def _credibility_digit(self, recency_score: float, overall: float) -> str:
        if overall >= 85 and recency_score >= 80:
            return '1'
        if overall >= 70:
            return '2'
        if overall >= 55:
            return '3'
        if overall >= 40:
            return '4'
        if overall >= 25:
            return '5'
        return '6'

    def _identify_factors(
        self,
        domain: str,
        domain_score: float,
        recency_score: float,
        expertise_score: float,
        bias_score: float,
        bias_flags: List[str],
    ) -> Dict[str, str]:
        factors: Dict[str, str] = {}
        if domain_score >= 85:
            factors['domain'] = 'High authority domain'
        elif domain_score <= 45:
            factors['domain'] = 'Low authority domain - verify claims'
        if recency_score >= 85:
            factors['recency'] = 'Recent information'
        elif recency_score <= 40:
            factors['recency'] = 'Outdated information - verify currency'
            if 'recency_risk' not in bias_flags:
                bias_flags.append('recency_risk')
        if expertise_score >= 80:
            factors['expertise'] = 'Expert source'
        elif expertise_score <= 45:
            factors['expertise'] = 'Limited expertise indicators'
        if bias_score >= 80:
            factors['bias'] = 'Balanced perspective'
        elif bias_score <= 50:
            factors['bias'] = 'Potential bias detected'
        return factors

    def _generate_recommendation(self, overall_score: float, reliability_code: str) -> str:
        letter = reliability_code[0] if reliability_code else 'F'
        if letter in ('A', 'B') and overall_score >= 75:
            return 'high_trust'
        if overall_score >= 60 and letter in ('A', 'B', 'C'):
            return 'moderate_trust'
        if overall_score >= 40:
            return 'low_trust'
        return 'verify'


def main() -> None:
    parser = argparse.ArgumentParser(description='Evaluate source credibility')
    parser.add_argument('--url', required=True)
    parser.add_argument('--title', required=True)
    parser.add_argument('--content', default=None)
    parser.add_argument('--publication-date', default=None)
    parser.add_argument('--author', default=None)
    parser.add_argument('--source-type', default=None)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()

    evaluator = SourceEvaluator()
    score = evaluator.evaluate_source(
        url=args.url,
        title=args.title,
        content=args.content,
        publication_date=args.publication_date,
        author=args.author,
        source_type=args.source_type,
    )
    if args.json:
        print(json.dumps(asdict(score), indent=2))
    else:
        print(f"reliability_code: {score.reliability_code}")
        print(f"authority_tier: {score.authority_tier}")
        print(f"overall: {score.overall_score}")
        print(f"recommendation: {score.recommendation}")
        print(f"bias_flags: {score.bias_flags}")


if __name__ == '__main__':
    main()
