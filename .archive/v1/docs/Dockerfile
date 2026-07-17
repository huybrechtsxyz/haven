FROM python:3.13-slim AS build

WORKDIR /docs

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN sphinx-build -b html . _build/html

FROM nginx:alpine

COPY --from=build /docs/_build/html /usr/share/nginx/html

EXPOSE 80
