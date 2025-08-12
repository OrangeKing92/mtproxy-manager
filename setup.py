#!/usr/bin/env python3
"""
Python MTProxy Setup Script
"""

from setuptools import setup, find_packages
import os

# Read README for long description
here = os.path.abspath(os.path.dirname(__file__))
try:
    with open(os.path.join(here, 'README.md'), encoding='utf-8') as f:
        long_description = f.read()
except FileNotFoundError:
    long_description = "Python implementation of MTProxy for Telegram"

# Read requirements
def read_requirements(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f if line.strip() and not line.startswith('#')]

setup(
    name='python-mtproxy',
    version='1.0.0',
    description='Python implementation of MTProxy for Telegram',
    long_description=long_description,
    long_description_content_type='text/markdown',
    author='MTProxy Team',
    author_email='admin@example.com',
    url='https://github.com/OrangeKing92/mtproxy-manager',
    packages=find_packages(),
    install_requires=read_requirements('requirements.txt'),
    extras_require={
        'dev': read_requirements('requirements-dev.txt'),
    },
    entry_points={
        'console_scripts': [
            'mtproxy=mtproxy.server:main',
            'mtproxy-cli=tools.mtproxy_cli:main',
        ],
    },
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Topic :: Internet :: Proxy Servers',
        'Topic :: Communications :: Chat',
    ],
    python_requires='>=3.8',
    include_package_data=True,
    zip_safe=False,
)
