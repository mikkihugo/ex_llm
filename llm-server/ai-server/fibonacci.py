def fibonacci(n):
    """
    Calculate the nth Fibonacci number recursively.

    Args:
        n (int): The position in the Fibonacci sequence (n >= 0)

    Returns:
        int: The nth Fibonacci number

    Examples:
        >>> fibonacci(0)
        0
        >>> fibonacci(1)
        1
        >>> fibonacci(5)
        5
        >>> fibonacci(10)
        55
    """
    if n < 0:
        raise ValueError("n must be non-negative")
    if n == 0:
        return 0
    elif n == 1:
        return 1
    else:
        return fibonacci(n - 1) + fibonacci(n - 2)

# Example usage
if __name__ == "__main__":
    print("Fibonacci sequence:")
    for i in range(11):
        print(f"F({i}) = {fibonacci(i)}")