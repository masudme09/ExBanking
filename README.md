# ExBanking
This is an attempt to implement in-memory banking like solution. Basically, I have played through different OTP behaviours like GenServers, Superviors etc. 

This project has 5 key components as follows:

Schema -> Actor -> Supervisor -> Processor -> Repository

- **Schema:** Schema represents basic sckeleton of the data structure and it also implements validation, low level trasformation and CRUD methods to interact with the repository.
- **Repository:** Its a low level layer where actual CRUD operation to data storage take place. Main purpose of this layer is to make states more persistent and separated. With the implementation of this layer, it is now possible to reduce the child nodes like process_limiter from the dynamic supervisor and re-initiate them with the previous state when required. I have used ETS - Erlang Term Storage as a in-memory data storage solution.

- **Actor:** Actor is the worker element that actually perform tasks and in this case they are GenServers.
- **Supervisor:** Supervisors are taking care of their child actors. They start, stop or re-start them when required. In this project, I have used ```UserLimiterSupervisor``` of ```DynamicSupervisor``` type behaviour. This supervisor is responsible for starting and stopping the ```ProcessLimiter``` actors through registry. ```ProcessLimiter``` actors are responsible for limiting the number of concurrent processes for a given user.

- **Processors:**  Processor can be considered as the logical layer of the application. It is responsible for the business logic and it is the only layer that can interact with the ```Schema``` and ```Repository```. I have used ```UserProcessors``` for processing user centric buisness logics.

## How to run

```elixir
iex -S mix
```

## How to test

I have used Application behaviour to start the application. So, to run the test cases, you need to start the application first.

Then run the following command.

```elixir
mix test
```

## Example Usage

Run the following commands in iex shell.

```elixir
# create user
iex> ExBanking.create_user("user1")
:ok
# get balance
iex> ExBanking.get_balance("user1", "USD")
{:ok, 0.0}

# deposit
iex> ExBanking.deposit("user1", 100, "USD")
{:ok, 100.0}

# withdraw
iex> ExBanking.withdraw("user1", 20.5, "USD")
{:ok, 79.5}

# send
iex> ExBanking.create_user("user2")
:ok
iex> ExBanking.send("user1", "user2", 10, "USD")
{:ok, 69.5, 10.0}

# error logging example
iex> ExBanking.send("user1", "user2", 100, "USD")
{:error, :not_enough_money}
iex> ExBanking.get_balance("user5", "USD")
{:error, :user_does_not_exist}
iex> ExBanking.deposit("user1", "100", "USD")
{:error, :wrong_arguments}
iex> ExBanking.withdraw("user1", "20.5", "USD")
{:error, :wrong_arguments}
iex> ExBanking.send("user1", "user5", 5, "USD")
{:error, :receiver_does_not_exist}
iex> ExBanking.send("user6", "user5", 5, "USD")
{:error, :sender_does_not_exist}
```
