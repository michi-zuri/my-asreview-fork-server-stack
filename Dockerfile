# First stage
FROM python:3.11-slim AS builder
WORKDIR /app

RUN apt-get update 