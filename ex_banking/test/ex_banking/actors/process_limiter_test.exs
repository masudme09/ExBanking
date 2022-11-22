defmodule ExBanking.Actors.ProcessLimiterTest do
  use ExUnit.Case, async: true
  alias ExBanking.ProcessLimiter

  setup do
    Application.stop(:ex_banking)
    Application.start(:ex_banking)
  end

  describe "check_free_space" do
    test "returns true if there is free space" do
      {:ok, user} = ExBanking.User.insert(%{user_name: "user1"})
      {:ok, pid} = ExBanking.UserLimiterSupervisor.start_child(user)
      assert ProcessLimiter.check_free_space(pid) == true
    end

    test "update active process count" do
      {:ok, user} = ExBanking.User.insert(%{user_name: "user1"})
      {:ok, pid} = ExBanking.UserLimiterSupervisor.start_child(user)
      ProcessLimiter.add_active_process(pid)
      assert ProcessLimiter.get_active_process_count(pid) == 1
      ProcessLimiter.add_active_process(pid)
      assert ProcessLimiter.get_active_process_count(pid) == 2

      ProcessLimiter.add_finished_process(pid)
      assert ProcessLimiter.get_active_process_count(pid) == 1
      ProcessLimiter.add_finished_process(pid)
      assert ProcessLimiter.get_active_process_count(pid) == 0

      assert ProcessLimiter.check_free_space(pid) == true
    end

    test "returns false if there is no free space" do
      {:ok, user} = ExBanking.User.insert(%{user_name: "user1"})
      {:ok, pid} = ExBanking.UserLimiterSupervisor.start_child(user)

      for _ <- 1..10, do: ProcessLimiter.add_active_process(pid)
      assert ProcessLimiter.check_free_space(pid) == false
    end

    test "multiple process limiter consistency" do
      {:ok, user1} = ExBanking.User.insert(%{user_name: "user1"})
      {:ok, pid1} = ExBanking.UserLimiterSupervisor.start_child(user1)
      {:ok, user2} = ExBanking.User.insert(%{user_name: "user2"})
      {:ok, pid2} = ExBanking.UserLimiterSupervisor.start_child(user2)

      for _ <- 1..10, do: ProcessLimiter.add_active_process(pid1)
      assert ProcessLimiter.check_free_space(pid1) == false
      assert ProcessLimiter.check_free_space(pid2) == true

      for _ <- 1..10, do: ProcessLimiter.add_active_process(pid2)
      assert ProcessLimiter.check_free_space(pid1) == false
      assert ProcessLimiter.check_free_space(pid2) == false

      for _ <- 1..10, do: ProcessLimiter.add_finished_process(pid1)
      assert ProcessLimiter.check_free_space(pid1) == true
      assert ProcessLimiter.check_free_space(pid2) == false

      for _ <- 1..10, do: ProcessLimiter.add_finished_process(pid2)
      assert ProcessLimiter.check_free_space(pid1) == true
      assert ProcessLimiter.check_free_space(pid2) == true
    end
  end
end
