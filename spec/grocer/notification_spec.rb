# encoding: UTF-8
require 'spec_helper'
require 'grocer/notification'
require 'grocer/shared_examples_for_notifications'

describe Grocer::Notification do
  describe 'binary format' do
    let(:payload_options) { { alert: 'hi', badge: 2, sound: 'siren.aiff' } }
    let(:payload) { payload_hash(notification) }

    include_examples 'a notification'

    it 'encodes alert as part of the payload' do
      notification.alert = 'Hello World!'
      expect(payload[:aps][:alert]).to eq('Hello World!')
    end

    it 'encodes badge as part of the payload' do
      notification.badge = 42
      expect(payload[:aps][:badge]).to eq(42)
    end

    it 'encodes sound as part of the payload' do
      notification.sound = 'siren.aiff'
      expect(payload[:aps][:sound]).to eq('siren.aiff')
    end

    it 'encodes category as part of the payload' do
      notification.category = 'a category'
      expect(payload[:aps][:category]).to eq('a category')
    end

    it 'encodes custom payload attributes' do
      notification.custom = { :foo => 'bar' }
      expect(payload[:foo]).to eq('bar')
    end

    it 'encodes UTF-8 characters' do
      notification.alert = '私'
      expect(payload[:aps][:alert].force_encoding("UTF-8")).to eq('私')
    end

    it 'encodes the payload length' do
      notification.alert = 'Hello World!'
      expect(bytes[43...45]).to eq([payload_bytes(notification).bytesize].pack('n'))
    end

    it 'encodes the payload length correctly for multibyte UTF-8 strings' do
      notification.alert = '私'
      expect(bytes[43...45]).to eq([payload_bytes(notification).bytesize].pack('n'))
    end

    context 'missing payload' do
      let(:payload_options) { Hash.new }

      it 'raises an error when none of alert, badge, or custom are specified' do
        -> { notification.to_bytes }.should raise_error(Grocer::NoPayloadError)
      end

      [{alert: 'hi'}, {badge: 1}, {custom: {a: 'b'}}].each do |payload|
        context "when #{payload.keys.first} exists, but not any other payload keys" do
          let(:payload_options) { payload }

          it 'does not raise an error' do
            -> { notification.to_bytes }.should_not raise_error
          end
        end
      end
    end

    context 'oversized payload' do
      let(:payload_options) { { alert: 'a' * (Grocer::Notification::MAX_PAYLOAD_SIZE + 1) } }

      it 'raises an error when the size of the payload in bytes is too large' do
        -> { notification.to_bytes }.should raise_error(Grocer::PayloadTooLargeError)
      end

      describe '#payload_too_large?' do
        subject { notification.payload_too_large? }

        it { should eq true }
      end
    end

    describe '#payload_too_large?' do
      subject { notification.payload_too_large? }

      context 'valid payload' do
        let(:payload_options) { { alert: 'Alert for a valid payload' } }

        it { should eq false }
      end

      context 'missing payload' do
        let(:payload_options) { Hash.new }

        it { should eq false }
      end

      context 'oversized payload' do
        let(:payload_options) { { alert: 'a' * (Grocer::Notification::MAX_PAYLOAD_SIZE + 1) } }

        it { should eq true }
      end
    end

    # the expectations are the minimum length to expect if we consider the payload is only the alert
    #   ex: "alert": "content of the alert" is 30
    describe '#payload_size' do
      subject { notification.payload_size }

      context 'valid payload' do
        let(:payload_options) { { alert: 'Alert for a valid payload' } }

        it { should > 34 }
      end

      context 'missing payload' do
        let(:payload_options) { Hash.new }

        it { should > 0 }
      end

      context 'oversized payload' do
        let(:payload_options) { { alert: 'a' * (Grocer::Notification::MAX_PAYLOAD_SIZE + 1) } }

        it { should > Grocer::Notification::MAX_PAYLOAD_SIZE }
      end
    end
  end
end
