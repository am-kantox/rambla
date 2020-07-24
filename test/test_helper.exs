ExUnit.start()

Application.ensure_all_started(:amqp)
Application.ensure_all_started(:phoenix_pubsub)
Application.ensure_all_started(:envio)
