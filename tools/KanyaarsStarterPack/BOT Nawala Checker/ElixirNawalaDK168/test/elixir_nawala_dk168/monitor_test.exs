defmodule ElixirNawalaDK168.MonitorTest do
  use ElixirNawalaDK168.DataCase, async: true

  alias ElixirNawalaDK168.Monitor
  alias ElixirNawalaDK168.Monitor.SflinkProfile
  alias ElixirNawalaDK168.Repo

  describe "create_sflink_profile/1" do
    test "rejects new profile when total profile count reaches max limit" do
      for i <- 1..Monitor.max_sflink_profiles() do
        %SflinkProfile{}
        |> SflinkProfile.changeset(%{
          name: "Profile#{i}",
          email: "profile#{i}@example.com",
          api_token: "sf_token#{i}",
          active: true
        })
        |> Repo.insert!()
      end

      assert {:error, :token_limit} =
               Monitor.create_sflink_profile(%{
                 "name" => "Profile Baru",
                 "api_token" => "sf_newtoken123"
               })
    end
  end
end
