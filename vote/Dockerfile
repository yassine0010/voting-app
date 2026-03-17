# --- Builder ---
FROM python:3.12-alpine3.22 AS builder
WORKDIR /app

# Only needed if some deps compile from source
RUN apk add --no-cache build-base

RUN python -m venv /opt/venv
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# --- Runtime ---
FROM python:3.12-alpine3.22
WORKDIR /app

# Create a non-root user/group
RUN addgroup -S app && adduser -S app -G app

# Copy venv + app
COPY --from=builder /opt/venv /opt/venv
COPY . .

# Use venv executables by default
ENV PATH="/opt/venv/bin:$PATH"

# Fix ownership so the non-root user can read the app
RUN chown -R app:app /app /opt/venv

USER app

EXPOSE 5000

# Gunicorn sometimes needs a writable temp dir; /tmp is the usual choice.
CMD ["gunicorn", "-b", "0.0.0.0:5000", "--worker-tmp-dir", "/tmp", "app:app"]
