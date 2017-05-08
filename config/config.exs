use Mix.Config

config :siva,
  max_queue: 10,
  max_workers: 5,
  min_workers: 1,
  scale_up: 5, # tasks in queue
  scale_down: 2, # workers waiting
  scale_interval: 200, # ms
  scale_delay: 1000 # ms time needed for worker to spin up
