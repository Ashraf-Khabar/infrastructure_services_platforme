from setuptools import setup, find_packages

setup(
    name="user-management-app",
    version="1.0.3",
    packages=find_packages(),
    install_requires=[
        "Flask>=1.1.2",
        "SQLAlchemy>=1.3.23",
        "requests>=2.25.1",
        "pytest>=6.2.2",
        "gunicorn>=20.0.4",
        "flask_sqlalchemy>=2.4.4"
    ],
    author="Axhraf KHABAR",
    author_email="khabarachraf@email.com",
    description="User Management Application",
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires='>=3.6',
)