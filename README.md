# Retail Database & Redis Cart Demo

This repository showcases two core aspects of modern database management:
1. **A comprehensive relational schema** for a retail application, using MySQL.
2. **A fast, in-memory caching mechanism** for a shopping cart using Redis.

## Features

- **Robust SQL Schema**: Defines a retail environment complete with customers, stores, products, inventory, orders, payments, and a loyalty program.
- **Transaction Management**: Demonstrates ACID properties with realistic `COMMIT` and `ROLLBACK` scenarios (e.g., successful vs. failed payments).
- **Schema Evolution**: Examples of how to gracefully add new features like a Loyalty Program via views and new tables without breaking existing apps.
- **Redis Shopping Cart**: A Python script demonstrating how to use Redis hashes to store, retrieve, update, and gracefully expire (TTL) shopping cart sessions.

## Files

- `retail_db.sql`: The complete MySQL database schema, constraints, data, queries, and transaction demos.
- `redis_cart.py`: Python script interacting with a local Redis server to manipulate cart items.

## Usage

### 1. MySQL Retail Database
1. Connect to your MySQL 8.0 instance.
2. Run the SQL script:
   ```bash
   mysql -u root -p < retail_db.sql
   ```

### 2. Redis Shopping Cart
1. Make sure you have Redis installed and running (`redis-server`).
2. Install the Redis python client:
   ```bash
   pip install redis
   ```
3. Run the script:
   ```bash
   python3 redis_cart.py
   ```

## Author

Ajay Prakash (Ajayprakashk7)
