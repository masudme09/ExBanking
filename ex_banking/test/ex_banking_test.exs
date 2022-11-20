defmodule ExBankingTest do
  use ExUnit.Case

  describe "user creation" do
    test "creates user" do
      assert ExBanking.create_user("user1") == :ok
    end

    test "fails to create user with wrong arguments" do
      assert ExBanking.create_user(1) == {:error, :wrong_arguments}
    end

    test "fails to create user that already exists" do
      ExBanking.create_user("user1")
      assert ExBanking.create_user("user1") == {:error, :user_already_exists}
    end
  end

  describe "deposit to user account" do
    test "deposits money to user account" do
      ExBanking.create_user("user1")
      assert ExBanking.deposit("user1", 100, "USD") == {:ok, 100}
    end

    test "fails to deposit money to user account with wrong arguments" do
      ExBanking.create_user("user1")
      assert ExBanking.deposit("user1", "100", "USD") == {:error, :wrong_arguments}
    end

    test "fails to deposit money to user account that does not exist" do
      assert ExBanking.deposit("user2", 100, "USD") == {:error, :user_does_not_exist}
    end

    test "can not deposit negative amount" do
      ExBanking.create_user("user1")
      assert ExBanking.deposit("user1", -100, "USD") == {:error, :wrong_arguments}
    end

    test "can not deposit zero amount" do
      ExBanking.create_user("user1")
      assert ExBanking.deposit("user1", 0, "USD") == {:error, :wrong_arguments}
    end

    test "deposit amount is rounded to two decimal places" do
      ExBanking.create_user("user1")
      assert ExBanking.deposit("user1", 100.123, "USD") == {:ok, 100.12}
    end

    # # will be done separately
    # test "performance test" do
    #   ExBanking.create_user("user1")
    #   assert ExBanking.deposit("user1", 100, "USD") == {:ok, 100}
    #   assert ExBanking.deposit("user1", 100, "USD") == {:ok, 200}
    #   assert ExBanking.deposit("user1", 100, "USD") == {:ok, 300}
    #   assert ExBanking.deposit("user1", 100, "USD") == {:ok, 400}
    #   assert ExBanking.deposit("user1", 100, "USD") == {:ok, 500}
    #   assert ExBanking.deposit("user1", 100, "USD") == {:error, :too_many_requests_to_user}
    # end
  end

  describe "withdraw from user account" do
    test "withdraws money from user account" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.withdraw("user1", 50, "USD") == {:ok, 50}
    end

    test "fails to withdraw money from user account with wrong arguments" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.withdraw("user1", "50", "USD") == {:error, :wrong_arguments}
    end

    test "fails to withdraw money from user account that does not exist" do
      assert ExBanking.withdraw("user2", 100, "USD") == {:error, :user_does_not_exist}
    end

    test "fails to withdraw money from user account that does not have enough money" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.withdraw("user1", 200, "USD") == {:error, :not_enough_money}
    end

    test "fails to withdraw money from user account that does not have enough money in requested currency" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.withdraw("user1", 50, "EUR") == {:error, :not_enough_money}
    end
  end

  describe "get balance of user account" do
    test "gets balance of user account" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.get_balance("user1", "USD") == {:ok, 100.00}
    end

    test "fails to get balance of user account with wrong arguments" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.get_balance("user1", 1) == {:error, :wrong_arguments}
    end

    test "fails to get balance of user account that does not exist" do
      assert ExBanking.get_balance("user2", "USD") == {:error, :user_does_not_exist}
    end

    test "get balance properly for multiple requested currency" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      ExBanking.deposit("user1", 150, "EUR")
      assert ExBanking.get_balance("user1", "USD") == {:ok, 100.00}
      assert ExBanking.get_balance("user1", "EUR") == {:ok, 150.00}
    end

    test "returned balance is rounded to two decimal places" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100.123, "USD")
      assert ExBanking.get_balance("user1", "USD") == {:ok, 100.12}
    end
  end

  describe "send money between user accounts" do
    test "sends money between user accounts" do
      ExBanking.create_user("user1")
      ExBanking.create_user("user2")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.send("user1", "user2", 50, "USD") == {:ok, 50}
    end

    test "fails to send money between user accounts with wrong arguments" do
      ExBanking.create_user("user1")
      ExBanking.create_user("user2")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.send("user1", "user2", "50", "USD") == {:error, :wrong_arguments}
    end

    test "fails to send money between user accounts that does not exist" do
      ExBanking.create_user("user1")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.send("user1", "user2", 50, "USD") == {:error, :user_does_not_exist}
    end

    test "fails to send money between user accounts that does not have enough money" do
      ExBanking.create_user("user1")
      ExBanking.create_user("user2")
      ExBanking.deposit("user1", 100, "USD")
      assert ExBanking.send("user1", "user2", 200, "USD") == {:error, :not_enough_money}
    end
  end
end
