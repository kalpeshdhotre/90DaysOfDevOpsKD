from flask import Flask
import psycopg2
import redis
import os

app = Flask(__name__)

@app.route("/")
def index():
    # Test Redis
    r = redis.Redis(host="cache", port=6379)
    r.incr("visits")
    visits = r.get("visits").decode()

    # Test Postgres
    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        database=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"]
    )
    cur = conn.cursor()
    cur.execute("SELECT version();")
    db_version = cur.fetchone()[0]
    conn.close()

    return f"<h1>Hello from Flask!</h1><p>Visits: {visits}</p><p>DB: {db_version}</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)