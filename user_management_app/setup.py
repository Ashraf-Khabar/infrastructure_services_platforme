from setuptools import setup, find_packages

setup(
    name="user_management_app",
    version="3.0.0",
    packages=find_packages(),
    install_requires=[
        "fastapi>=0.104.1",
        "uvicorn>=0.24.0",
        "sqlalchemy>=2.0.23",
        "flask>=2.3.3",
        "requests>=2.31.0",
    ],
    extras_require={
        "test": [
            "pytest>=7.4.0",
            "robotframework>=6.1.1",
            "robotframework-requests>=0.9.4",
        ],
    },
    author="Votre Nom",
    author_email="votre.email@example.com",
    description="Application de gestion d'utilisateurs avec API FastAPI",
    keywords="fastapi users management",
)