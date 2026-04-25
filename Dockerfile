FROM python:3.12-slim

WORKDIR /app

# intall deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# copy app file
COPY . .

# expose app port
EXPOSE 8082

# will be overriden by docker compose
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8082"]
