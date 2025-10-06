def fibonacci(n):
    """
    Calculate the nth Fibonacci number recursively.
    
    The Fibonacci sequence is: 0, 1, 1, 2, 3, 5, 8, 13, 21, ...
    Where each number is the sum of the two preceding ones.
    
    Args:
        n (int): The position in the Fibonacci sequence (0-indexed)
        
    Returns:
        int: The nth Fibonacci number
        
    Raises:
        ValueError: If n is negative
        
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
    
    # Base cases
    if n == 0:
        return 0
    if n == 1:
        return 1
    
    # Recursive case
    return fibonacci(n - 1) + fibonacci(n - 2)


if __name__ == "__main__":
    # Example usage
    print("Fibonacci sequence (first 10 numbers):")
    for i in range(10):
        print(f"fibonacci({i}) = {fibonacci(i)}")
