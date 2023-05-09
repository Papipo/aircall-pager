# frozen_string_literal: true

# The Pager service domain logic
class Pager
  ACK_TIMEOUT = 60 * 15
  attr_reader :timer, :escalation, :repo, :notifier

  def initialize(timer:, escalation:, repo:, notifier:)
    @timer = timer
    @escalation = escalation
    @repo = repo
    @notifier = notifier
  end

  def alert(service_id:, message:)
    return unless repo.unhealthy(service_id)

    escalation.recipients(service_id:, level: 1).each do |recipient|
      notifier.call(recipient:, message:)
    end
    timer.set(id: service_id, seconds: ACK_TIMEOUT)
  end

  def timeout(service_id)
    alert = repo.escalate(service_id)
    return unless alert

    escalation.recipients(service_id:, level: alert.level).each do |recipient|
      notifier.call(recipient:, message: alert.message)
    end
    timer.set(id: service_id, seconds: ACK_TIMEOUT)
  end

  def healthy(service_id)
    repo.healthy(service_id)
  end
end
