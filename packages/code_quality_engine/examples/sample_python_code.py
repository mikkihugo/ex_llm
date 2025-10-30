#!/usr/bin/env python3
"""
Sample Python code for benchmarking the Code Quality Engine.

This file contains representative Python code used for performance testing.
"""

import asyncio
from typing import List, Optional, Dict, Any
from dataclasses import dataclass


def factorial(n: int) -> int:
    """Calculate the factorial of a number using recursion."""
    if n <= 1:
        return 1
    return n * factorial(n - 1)


def sum_list(numbers: List[int]) -> int:
    """Calculate the sum of a list of numbers."""
    return sum(numbers)


def find_maximum(numbers: List[int]) -> Optional[int]:
    """Find the maximum value in a list."""
    return max(numbers) if numbers else None


def is_prime(n: int) -> bool:
    """Check if a number is prime."""
    if n <= 1:
        return False
    if n <= 3:
        return True
    if n % 2 == 0 or n % 3 == 0:
        return False

    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True


def process_user_data(data: str) -> Dict[str, str]:
    """Process user data from a string format."""
    if not data:
        raise ValueError("Data cannot be empty")

    result = {}
    for line in data.split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            result[key.strip()] = value.strip()

    if not result:
        raise ValueError("No valid key-value pairs found")

    return result


@dataclass
class User:
    """User data structure."""
    id: int
    name: str
    email: str
    active: bool


def process_users(users: List[User]) -> List[User]:
    """Process a list of users, filtering and cleaning."""
    return [
        User(
            id=user.id,
            name=user.name.strip(),
            email=user.email,
            active=user.active
        )
        for user in users
        if user.active
    ]


async def fetch_user_data(user_id: int) -> User:
    """Simulate fetching user data asynchronously."""
    await asyncio.sleep(0.01)  # Simulate network delay

    return User(
        id=user_id,
        name=f"User {user_id}",
        email=f"user{user_id}@example.com",
        active=user_id % 2 == 0
    )


def find_first(items: List[Any], predicate) -> Optional[Any]:
    """Find the first item that matches a predicate."""
    return next((item for item in items if predicate(item)), None)


def binary_search(arr: List[int], target: int) -> Optional[int]:
    """Perform binary search on a sorted array."""
    left, right = 0, len(arr)

    while left < right:
        mid = left + (right - left) // 2

        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid

    return None


class AppError(Exception):
    """Custom application error."""
    pass


def validate_input(input_str: str) -> None:
    """Validate input string."""
    if not input_str:
        raise AppError("Input cannot be empty")

    if len(input_str) > 1000:
        raise AppError("Input too long")


def process_numbers(numbers: List[int]) -> List[int]:
    """Process a list of numbers with filtering and transformation."""
    return [n * 2 for n in numbers if n > 0]


async def main() -> None:
    """Main function demonstrating usage."""
    print("Code Quality Engine - Sample Python Code")

    # Basic calculations
    fact = factorial(5)
    print(f"5! = {fact}")

    numbers = [1, 2, 3, 4, 5]
    total = sum_list(numbers)
    print(f"Sum: {total}")

    # Prime checking
    primes = [n for n in range(1, 20) if is_prime(n)]
    print(f"Primes < 20: {primes}")

    # User data processing
    user_data = "name: John Doe\nemail: john@example.com\nactive: true"
    try:
        data = process_user_data(user_data)
        print(f"User data: {data}")
    except ValueError as e:
        print(f"Error: {e}")

    # Async operations
    try:
        user = await fetch_user_data(42)
        print(f"Fetched user: {user}")
    except Exception as e:
        print(f"Error: {e}")

    # Complex data processing
    users = [
        User(1, " Alice ", "alice@example.com", True),
        User(2, " Bob ", "bob@example.com", False),
        User(3, " Charlie ", "charlie@example.com", True),
    ]

    processed_users = process_users(users)
    print(f"Active users: {len(processed_users)}")

    # Algorithm demonstration
    sorted_array = [1, 3, 5, 7, 9, 11, 13, 15]
    index = binary_search(sorted_array, 7)
    if index is not None:
        print(f"Found 7 at index {index}")

    # Iterator processing
    processed = process_numbers([-2, -1, 0, 1, 2, 3])
    print(f"Processed numbers: {processed}")


if __name__ == "__main__":
    asyncio.run(main())</content>
<parameter name="filePath">/home/mhugo/code/singularity/packages/code_quality_engine/examples/sample_python_code.py