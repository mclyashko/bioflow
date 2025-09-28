import Config

config :libcluster,
  topologies: [
    bioflow_cluster: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]
