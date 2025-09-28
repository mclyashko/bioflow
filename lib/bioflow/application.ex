defmodule Bioflow.Application do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      {Cluster.Supervisor, [topologies, [name: Bioflow.ClusterSupervisor]]},
      {Horde.Registry, [name: Bioflow.HordeRegistry, keys: :unique, members: :auto]},
      {Horde.DynamicSupervisor,
       [name: Bioflow.HordeSupervisor, strategy: :one_for_one, members: :auto]}
    ]

    opts = [strategy: :one_for_one, name: Bioflow.ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
