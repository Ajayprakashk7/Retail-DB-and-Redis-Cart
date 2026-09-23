"""
Redis Shopping Cart Demonstration
Practical exercise: shopping cart data in Redis, used from Python.

Needs a running Redis server and the redis-py client:
    pip install redis
    redis-server

Run with:
    python3 redis_cart.py
"""

import json
import time

import redis


# ------------------------------------------------------------
# Connection
# ------------------------------------------------------------
# decode_responses=True gives back str instead of bytes, so the
# printed output is readable.
def connect_to_redis():
    client = redis.Redis(
        host="localhost",
        port=6379,
        db=0,
        decode_responses=True,
    )
    client.ping()          # fails here if the server is not running
    return client


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
# One cart = one Redis hash, for example "cart:1001".
# Field = product id, value = small JSON string with name and quantity.
# The whole cart is under one key, so we can read, expire or delete it
# with one command.

CART_KEY = "cart:1001"


def add_item(client, cart_key, product_id, product_name, quantity):
    item = {"product_name": product_name, "quantity": quantity}
    client.hset(cart_key, str(product_id), json.dumps(item))


def get_cart(client, cart_key):
    raw = client.hgetall(cart_key)
    return {int(pid): json.loads(value) for pid, value in raw.items()}


def print_cart(client, cart_key):
    cart = get_cart(client, cart_key)

    if not cart:
        print(f"  {cart_key} is empty or does not exist.")
        return

    print(f"  {'Product ID':<12}{'Product Name':<25}{'Quantity':>9}")
    print(f"  {'-' * 46}")

    for product_id in sorted(cart):
        item = cart[product_id]
        print(
            f"  {product_id:<12}"
            f"{item['product_name']:<25}"
            f"{item['quantity']:>9}"
        )


def banner(title):
    print()
    print("=" * 58)
    print(title)
    print("=" * 58)


# ------------------------------------------------------------
# Step 1: store and retrieve shopping cart data
# ------------------------------------------------------------
def step_1_store_and_retrieve(client):
    banner("STEP 1: Store and retrieve shopping cart data")

    client.delete(CART_KEY)          # start clean

    add_item(client, CART_KEY, 102, "Mechanical Keyboard", 1)
    add_item(client, CART_KEY, 110, "Desk Lamp", 2)
    add_item(client, CART_KEY, 104, "USB-C Cable", 3)

    print(f"Stored 3 items under key '{CART_KEY}'.")

    print(f"\nRetrieved cart '{CART_KEY}':")
    print_cart(client, CART_KEY)

    print(
        f"\nNumber of distinct products in cart: "
        f"{client.hlen(CART_KEY)}"
    )


# ------------------------------------------------------------
# Step 2: update and delete
# ------------------------------------------------------------
def step_2_update_and_delete(client):
    banner("STEP 2: Update and delete")

    # --- update the quantity of one product ---
    product_id = 110
    cart = get_cart(client, CART_KEY)

    print(
        f"Quantity of product {product_id} before update: "
        f"{cart[product_id]['quantity']}"
    )

    # HSET on an existing hash field replaces its previous value.
    # This is the Redis equivalent of updating the cart item's value.
    add_item(
        client,
        CART_KEY,
        product_id,
        cart[product_id]["product_name"],
        5,
    )

    print(f"Updated quantity of product {product_id} to 5.")

    print("\nCart after the update:")
    print_cart(client, CART_KEY)

    # --- delete the whole cart ---
    print(
        f"\nDoes '{CART_KEY}' exist before delete? "
        f"{bool(client.exists(CART_KEY))}"
    )

    deleted = client.delete(CART_KEY)
    print(f"DEL returned {deleted} (number of keys removed).")

    print(
        f"Does '{CART_KEY}' exist after delete?  "
        f"{bool(client.exists(CART_KEY))}"
    )

    print("\nReading the deleted cart:")
    print_cart(client, CART_KEY)


# ------------------------------------------------------------
# ------------------------------------------------------------
# Step 3: expiration (TTL)
# ------------------------------------------------------------
def step_3_ttl(client):
    banner("STEP 3: Expiration (TTL)")

    # Cart was deleted in Step 2, so build a small one again.
    add_item(client, CART_KEY, 101, "Wireless Mouse", 1)
    add_item(client, CART_KEY, 105, "Laptop Stand", 1)

    print(f"Rebuilt cart '{CART_KEY}' with 2 items.")

    # TTL is -1 when the key exists but has no expiry.
    print(
        f"\nTTL before EXPIRE is set: {client.ttl(CART_KEY)} "
        f"(-1 means the key never expires)"
    )

    client.expire(CART_KEY, 300)
    print("Set an expiry of 300 seconds on the cart.")

    print(
        f"Remaining TTL immediately after: "
        f"{client.ttl(CART_KEY)} seconds"
    )

    time.sleep(3)

    print(
        f"Remaining TTL after waiting 3 seconds: "
        f"{client.ttl(CART_KEY)} seconds"
    )

    # Short TTL so we can actually see a key expire.
    short_key = "cart:9999"

    client.hset(
        short_key,
        "108",
        json.dumps(
            {
                "product_name": "Notebook A5",
                "quantity": 1,
            }
        ),
    )

    client.expire(short_key, 2)

    print(f"\nCreated '{short_key}' with a 2 second TTL.")
    print(
        f"  exists now:          "
        f"{bool(client.exists(short_key))}"
    )

    time.sleep(3)

    print(
        f"  exists after 3 sec:  "
        f"{bool(client.exists(short_key))}"
    )

    print(
        f"  TTL after expiry:    "
        f"{client.ttl(short_key)} "
        f"(-2 means the key no longer exists)"
    )

    print("""
Why TTL is useful for cart and session data
-------------------------------------------
An abandoned cart is not useful later, but without an expiry it would stay in
memory indefinitely. Redis keeps data in RAM, so this growth consumes memory.
A TTL allows Redis to remove the key automatically after the specified period,
without requiring a separate cleanup job.

It is also useful for shopping carts because an abandoned cart may contain
old information while product prices and stock can change. Expiring stale
cart data helps prevent old data from remaining indefinitely.

The same approach can be used for login sessions, where the TTL can make an
idle session expire automatically.

If the application wants an active cart to remain available for longer, it
can explicitly refresh the TTL using the EXPIRE command when the customer
interacts with the cart. Writing to the cart does not automatically reset
its TTL.
""")


# ------------------------------------------------------------
def main():
    try:
        client = connect_to_redis()

    except redis.ConnectionError:
        print("Could not connect to Redis on localhost:6379.")
        print(
            "Start the server with 'redis-server' and run this "
            "script again."
        )
        return

    print("Connected to Redis at localhost:6379")

    step_1_store_and_retrieve(client)
    step_2_update_and_delete(client)
    step_3_ttl(client)

    # Clean up the main cart after the demonstration.
    client.delete(CART_KEY)

    print("Done.")


if __name__ == "__main__":
    main()