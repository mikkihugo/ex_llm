//! Sample Rust code for benchmarking
//!
//! This file contains representative Rust code used for performance testing.

use std::collections::HashMap;

/// Calculate the factorial of a number using recursion
pub fn factorial(n: u64) -> u64 {
    match n {
        0 | 1 => 1,
        _ => n * factorial(n - 1),
    }
}

/// Calculate the sum of a vector of numbers
pub fn sum_vector(numbers: &[i32]) -> i32 {
    numbers.iter().sum()
}

/// Find the maximum value in a vector
pub fn find_max(numbers: &[i32]) -> Option<i32> {
    numbers.iter().max().copied()
}

/// Check if a number is prime
pub fn is_prime(n: u64) -> bool {
    if n <= 1 {
        return false;
    }
    if n <= 3 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }

    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }
    true
}

/// Process user data with error handling
pub fn process_user_data(data: &str) -> Result<HashMap<String, String>, String> {
    if data.is_empty() {
        return Err("Data cannot be empty".to_string());
    }

    let mut result = HashMap::new();

    for line in data.lines() {
        if let Some((key, value)) = line.split_once(':') {
            let key = key.trim().to_string();
            let value = value.trim().to_string();
            result.insert(key, value);
        }
    }

    if result.is_empty() {
        return Err("No valid key-value pairs found".to_string());
    }

    Ok(result)
}

/// Complex data structure processing
#[derive(Debug, Clone)]
pub struct User {
    pub id: u64,
    pub name: String,
    pub email: String,
    pub active: bool,
}

pub fn process_users(users: Vec<User>) -> Vec<User> {
    users
        .into_iter()
        .filter(|user| user.active)
        .map(|mut user| {
            user.name = user.name.trim().to_string();
            user
        })
        .collect()
}

/// Async function example
pub async fn fetch_user_data(user_id: u64) -> Result<User, String> {
    // Simulate async operation
    tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;

    Ok(User {
        id: user_id,
        name: format!("User {}", user_id),
        email: format!("user{}@example.com", user_id),
        active: user_id % 2 == 0,
    })
}

/// Generic function with constraints
pub fn find_first<T, F>(items: &[T], predicate: F) -> Option<&T>
where
    F: Fn(&T) -> bool,
{
    items.iter().find(|item| predicate(item))
}

/// Complex algorithm: binary search
pub fn binary_search(arr: &[i32], target: i32) -> Option<usize> {
    let mut left = 0;
    let mut right = arr.len();

    while left < right {
        let mid = left + (right - left) / 2;

        match arr[mid].cmp(&target) {
            std::cmp::Ordering::Equal => return Some(mid),
            std::cmp::Ordering::Less => left = mid + 1,
            std::cmp::Ordering::Greater => right = mid,
        }
    }

    None
}

/// Error handling with custom types
#[derive(Debug)]
pub enum AppError {
    InvalidInput(String),
    NetworkError(String),
    DatabaseError(String),
}

pub fn validate_input(input: &str) -> Result<(), AppError> {
    if input.is_empty() {
        return Err(AppError::InvalidInput("Input cannot be empty".to_string()));
    }

    if input.len() > 1000 {
        return Err(AppError::InvalidInput("Input too long".to_string()));
    }

    Ok(())
}

/// Iterator processing
pub fn process_numbers(numbers: Vec<i32>) -> Vec<i32> {
    numbers
        .into_iter()
        .filter(|&n| n > 0)
        .map(|n| n * 2)
        .collect()
}

/// Main function demonstrating usage
#[tokio::main]
pub async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Code Quality Engine - Sample Rust Code");

    // Basic calculations
    let fact = factorial(5);
    println!("5! = {}", fact);

    let numbers = vec![1, 2, 3, 4, 5];
    let sum = sum_vector(&numbers);
    println!("Sum: {}", sum);

    // Prime checking
    let primes: Vec<u64> = (1..20).filter(|&n| is_prime(n)).collect();
    println!("Primes < 20: {:?}", primes);

    // User data processing
    let user_data = "name: John Doe\nemail: john@example.com\nactive: true";
    match process_user_data(user_data) {
        Ok(data) => println!("User data: {:?}", data),
        Err(e) => println!("Error: {}", e),
    }

    // Async operations
    match fetch_user_data(42).await {
        Ok(user) => println!("Fetched user: {:?}", user),
        Err(e) => println!("Error: {}", e),
    }

    // Complex data processing
    let users = vec![
        User {
            id: 1,
            name: " Alice ".to_string(),
            email: "alice@example.com".to_string(),
            active: true,
        },
        User {
            id: 2,
            name: " Bob ".to_string(),
            email: "bob@example.com".to_string(),
            active: false,
        },
        User {
            id: 3,
            name: " Charlie ".to_string(),
            email: "charlie@example.com".to_string(),
            active: true,
        },
    ];

    let processed_users = process_users(users);
    println!("Active users: {}", processed_users.len());

    // Algorithm demonstration
    let sorted_array = vec![1, 3, 5, 7, 9, 11, 13, 15];
    if let Some(index) = binary_search(&sorted_array, 7) {
        println!("Found 7 at index {}", index);
    }

    // Iterator processing
    let processed = process_numbers(vec![-2, -1, 0, 1, 2, 3]);
    println!("Processed numbers: {:?}", processed);

    Ok(())
}
