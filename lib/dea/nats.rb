# coding: UTF-8

require "steno"
require "steno/core_ext"
require "nats/client"

module Dea
  class Nats
    attr_reader :bootstrap
    attr_reader :config

    def initialize(bootstrap, config)
      @bootstrap = bootstrap
      @config = config
    end

    def start
      subscribe("healthmanager.start") do |message|
        bootstrap.handle_health_manager_start(message)
      end

      subscribe("router.start") do |message|
        bootstrap.handle_router_start(message)
      end

      subscribe("dea.status") do |message|
        bootstrap.handle_dea_status(message)
      end

      subscribe("dea.#{config[:uuid]}.start") do |message|
        bootstrap.handle_dea_directed_start(message)
      end

      subscribe("dea.locate") do |message|
        bootstrap.handle_dea_locate(message)
      end

      subscribe("dea.stop") do |message|
        bootstrap.handle_dea_stop(message)
      end

      subscribe("dea.update") do |message|
        bootstrap.handle_dea_update(message)
      end

      subscribe("dea.find.droplet") do |message|
        bootstrap.handle_dea_find_droplet(message)
      end

      subscribe("droplet.status") do |message|
        bootstrap.handle_droplet_status(message)
      end
    end

    def nats
      @nats ||= create_nats_client
    end

    def create_nats_client
      logger.info "Connecting to NATS on #{config["nats_uri"]}"
      ::NATS.connect(:uri => config["nats_uri"])
    end

    class Message
      def self.decode(nats, subject, raw_data, respond_to)
        data = Yajl::Parser.parse(raw_data)
        new(nats, subject, data, respond_to)
      end

      attr_reader :nats
      attr_reader :subject
      attr_reader :data
      attr_reader :respond_to

      def initialize(nats, subject, data, respond_to)
        @nats       = nats
        @subject    = subject
        @data       = data
        @respond_to = respond_to
      end

      def respond(data)
        message = response(data)
        message.publish
      end

      def response(data)
        new(nats, respond_to, data, nil)
      end

      def publish
        nats.publish(subject, Yajl::Encoder.encode(data))
      end
    end

    private

    def logger
      @logger ||= self.class.logger
    end

    def subscribe(subject)
      nats.subscribe(subject) do |raw_data, respond_to|
        message = Message.decode(nats, subject, raw_data, respond_to)
        yield message
      end
    end
  end
end