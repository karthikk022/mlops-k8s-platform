FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY handler.py .

ENV MODEL_URI="models:/default/latest"
ENV MODEL_VERSION="1.0.0"

EXPOSE 8080

CMD ["python", "-m", "kserve", "serve", "--model", "handler.py"]
