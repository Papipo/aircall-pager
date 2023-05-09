require "pager"

RSpec.describe Pager do
  let(:timer) { double("Timer service client", set: true) }
  let(:escalation) { double("Escalation service client") }
  let(:notifier) { double("Notifier service client", call: true) }
  let(:repo) { double("Pager persitence", unhealthy: 1) }
  let(:service_id) { "some-fake-id" }
  let(:message) { "This message describes the issue" }
  let(:recipient) { double("This represents a transport [SMS | Email] + address/phone tuple") }

  let(:pager) do
    Pager.new(timer: timer, escalation: escalation, repo: repo, notifier: notifier)
  end

  describe "alert on Healthy service" do
    before do
      allow(escalation).to receive(:recipients).with(service_id: service_id, level: 1).and_return([recipient])
    end

    after { pager.alert(service_id: service_id, message: message) }

    it "switches the service to Unhealthy" do
      expect(repo).to receive(:unhealthy).with(service_id).and_return(1)
    end

    it "notifies all targets of the first level of the escalation policy" do
      expect(notifier).to receive(:call).once.with({recipient: recipient, message: message})
    end

    it "sets a 15-minutes acknowledgement delay" do
      expect(timer).to receive(:set).with({id: service_id, seconds: 60 * 15})
    end
  end

  describe "timeout on Unhealthy service" do
    let(:level) { 2 }
    let(:alert) { double("Alert", level: level, message: message) }

    before do
      allow(repo).to receive(:escalate).with(service_id).and_return(alert)
      allow(escalation).to receive(:recipients).with(service_id: service_id, level: level).and_return([recipient])
    end

    after { pager.timeout(service_id) }

    it "notifies all targets of the first level of the escalation policy" do
      expect(notifier).to receive(:call).once.with({recipient: recipient, message: message})
    end

    it "sets a 15-minutes acknowledgement delay" do
      expect(timer).to receive(:set).with({id: service_id, seconds: 60 * 15})
    end
  end
end