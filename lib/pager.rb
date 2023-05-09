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
    level = repo.unhealthy(service_id)
    escalation.recipients(service_id: service_id, level: level).each do |recipient|
      notifier.call(recipient: recipient, message: message)
    end
    timer.set(id: service_id, seconds: ACK_TIMEOUT)
  end

  def timeout(service_id)
    alert = repo.escalate(service_id)
    return unless alert
    
    escalation.recipients(service_id: service_id, level: alert.level).each do |recipient|
      notifier.call(recipient: recipient, message: alert.message)
    end
    timer.set(id: service_id, seconds: ACK_TIMEOUT)
  end
end