# frozen_string_literal: true

require 'rollout/feature'
require 'rollout/version'
require 'redis'
require 'json'

class Rollout

  class Error < StandardError; end

  attr_reader :storage

  def initialize(storage)
    @storage = storage
    @cache_enabled = false
    @degrade_enabled = false
  end

  def with_cache(expires_in: 300)
    @cache_enabled = true
    @cache_time = expires_in
    @cache = {}

    self
  end

  def with_degrade(min: 100, threshold: 0.1)
    @degrade_enabled = true
    @degrade_min = min
    @degrade_threshold = threshold

    self
  end

  def activate(feature_name, percentage=100)
    data = { percentage: percentage }
    feature = Feature.new(feature_name, data)
    @cache[feature_name] = {
      feature: feature,
      timestamp: Time.now.to_i
    } if @cache_enabled
    save(feature) == "OK"
  end

  def activate_percentage(feature_name, percentage)
    activate(feature_name, percentage)
  end

  def deactivate(feature_name)
    del(feature_name)
  end

  def active?(feature_name, determinator = nil)
    feature = get(feature_name, determinator)
    return false unless feature

    active = feature.active?(determinator)

    if active && @degrade_enabled
      feature.add_request
      save(feature)
    end

    active
  end

  def with_feature_flag(feature_name, determinator = nil, &block)
    yield if active?(feature_name, determinator)
  rescue => e
    feature = get(feature_name, determinator)
    if @degrade_enabled && feature
      feature.add_error
      save(feature)

      deactivate(feature_name) if degraded?(feature)
    end
    raise e
  end

  def features
    keys = @storage.keys("#{key_prefix}:*")
    return [] if keys.empty?

    keys.map do |key|
      data = @storage.get(key)
      next unless data

      feature_name = key.gsub("#{key_prefix}:", '')
      Feature.new(feature_name, JSON.parse(data, symbolize_names: true)).to_h
    end
  end

  def clean_cache
    return unless @cache_enabled

    @cache = {}
  end

  def migrate_from_rollout_format
    keys = @storage.keys('feature:*')

    keys.each do |old_key|
      new_key = old_key.gsub('feature:', 'feature-rollout-redis:')
      old_data = @storage.get(old_key)

      if old_data
        percentage = old_data.split('|')[0].to_i

        new_data = {
          percentage: percentage,
          requests: 0,
          errors: 0
        }.to_json

        @storage.set(new_key, new_data)

        puts "Migrated key: #{old_key} to #{new_key} with data #{new_data}"
      end
    end
  end

  private

  def get(feature_name, determinator = nil)
    feature = from_redis(feature_name)
    return unless feature

    @cache[feature_name] = {
      feature: feature,
      timestamp: Time.now.to_i
    } if @cache_enabled

    feature
  rescue ::Redis::BaseError => e
    cached_feature = from_cache(feature_name)
    raise Rollout::Error.new(e) unless cached_feature

    cached_feature
  end

  def save(feature)
    @storage.set(key(feature.name), feature.data.to_json)
  end
  
  def del(feature_name)
    @storage.del(key(feature_name)) == 1
  end

  def from_cache(feature_name)
    return nil unless @cache_enabled

    cached = @cache[feature_name]

    if expired?(cached[:timestamp])
      @cache.delete(feature_name)
      return nil
    end

    cached[:feature]
  end

  def from_redis(feature_name)
    data = @storage.get(key(feature_name))
    return unless data
    Feature.new(feature_name, JSON.parse(data, symbolize_names: true))
  end

  def expired?(timestamp)
    Time.now.to_i - timestamp > @cache_time
  end

  def degraded?(feature)
    return false if !@degrade_enabled
    return false if feature.requests < @degrade_min

    feature.errors > @degrade_threshold * feature.requests
  end

  def key(name)
    "#{key_prefix}:#{name}"
  end

  def key_prefix
    "feature-rollout-redis"
  end
end