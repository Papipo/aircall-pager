# frozen_string_literal: true

require 'pager'

RSpec.describe Pager do
  shared_examples 'noop' do
    it "doesn't set the timer" do
      expect(timer).not_to receive(:set)
    end

    it "doesn't send any notifications" do
      expect(notifier).not_to receive(:call)
    end
  end

  let(:timer) { double('Timer service client', set: true) }
  let(:escalation) { double('Escalation service client') }
  let(:notifier) { double('Notifier service client', call: true) }
  let(:repo) { double('Pager persitence', unhealthy: true, healthy: true) }
  let(:service_id) { 'some-fake-id' }
  let(:message) { 'This message describes the issue' }
  let(:recipient) { double('This represents a transport [SMS | Email] + address/phone tuple') }

  let(:pager) do
    Pager.new(timer:, escalation:, repo:, notifier:)
  end

  describe 'alert on Healthy service' do
    before do
      allow(escalation).to receive(:recipients).with(service_id:, level: 1).and_return([recipient])
    end

    after { pager.alert(service_id:, message:) }

    it 'switches the service to Unhealthy' do
      expect(repo).to receive(:unhealthy).with(service_id)
    end

    it 'notifies all targets of the first level of the escalation policy' do
      expect(notifier).to receive(:call).once.with({ recipient:, message: })
    end

    it 'sets a 15-minutes acknowledgement delay' do
      expect(timer).to receive(:set).with({ id: service_id, seconds: 60 * 15 })
    end
  end

  describe 'timeout on Unhealthy service' do
    let(:level) { 2 }
    let(:alert) { double('Alert', level:, message:) }

    before do
      allow(repo).to receive(:escalate).with(service_id).and_return(alert)
      allow(escalation).to receive(:recipients).with(service_id:, level:).and_return([recipient])
    end

    after { pager.timeout(service_id) }

    it 'notifies all targets of the first level of the escalation policy' do
      expect(notifier).to receive(:call).once.with({ recipient:, message: })
    end

    it 'sets a 15-minutes acknowledgement delay' do
      expect(timer).to receive(:set).with({ id: service_id, seconds: 60 * 15 })
    end
  end

  describe 'timeout on Healthy service' do
    before do
      allow(repo).to receive(:escalate).with(service_id).and_return(false)
    end

    after { pager.timeout(service_id) }

    it_behaves_like 'noop'
  end

  describe 'alert on Unhealthy services' do
    before do
      allow(repo).to receive(:unhealthy).with(service_id).and_return(false)
    end

    after { pager.alert(service_id:, message: 'This is a completely new alert') }

    it_behaves_like 'noop'
  end

  describe 'acknowledgment and timeout' do
    before do
      allow(repo).to receive(:healthy).with(service_id)
      allow(repo).to receive(:escalate).with(service_id).and_return(false)
    end

    after do
      pager.healthy(service_id)
      pager.timeout(service_id)
    end

    it 'persist healthy status' do
      expect(repo).to receive(:healthy).with(service_id)
    end

    it "doesn't set a new timer" do
      expect(timer).not_to receive(:set)
    end

    it 'notifies nobody' do
      expect(notifier).not_to receive(:call)
    end
  end
end
