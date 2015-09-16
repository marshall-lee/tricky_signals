require 'spec_helper'

describe TrickySignals do
  let(:pid) { Process.pid }

  def handlers
    subject.instance_variable_get :@handlers
  end

  def send_usr1!
    Process.kill 'USR1', pid
  end

  def wait_signals!
    # TODO: how to do it smarter?
    sleep 0.005
  end

  shared_context 'previously defined USR1' do
    around do |example|
      old_usr1 = Signal.trap 'USR1' do
        usr1_handler()
      end
      example.run
      Signal.trap 'USR1', old_usr1
    end
  end

  shared_examples '#stop behavior' do
    it 'changes `started?` property to false' do
      expect {
        subject.stop!
      }.to change(subject, :started?).from(true).to(false)
    end

    it 'decreases thread count by 1' do
      expect {
        subject.stop!
      }.to change { Thread.list.length }.by(-1)
    end
  end

  shared_examples '#trap behavior' do
    before { @buffer = [] }
    after { subject.untrap('USR1') }

    it 'traps system signals for real!' do
      subject.trap('USR1') do
        @buffer << :usr1
      end

      expect {
        send_usr1!
        send_usr1!
        wait_signals!
      }.to change(@buffer, :length).by(2)
    end

    it 'registers a handler method' do
      subject.trap('USR1') { }
      expect(handlers).to have_key('USR1')
      expect(handlers['USR1']).to be_kind_of(Proc)
    end

    describe 'trapping by signal number' do
      it 'works well too' do
        subject.trap(10) do
          @buffer << :usr1
        end

        expect {
          send_usr1!
          send_usr1!
          wait_signals!
        }.to change(@buffer, :length).by(2)
      end

      it 'registers a handler method' do
        subject.trap(10) { }
        expect(handlers).to have_key('USR1')
        expect(handlers['USR1']).to be_kind_of(Proc)
      end
    end

    describe 'with one argument block' do
      it 'passes signal name as a first argument' do
        subject.trap('USR1') do |signal|
          @buffer << signal
        end

        send_usr1!
        send_usr1!
        wait_signals!

        expect(@buffer).to eq(['USR1', 'USR1'])
      end

      describe 'trapping by signal number' do
        it 'passes string signal name as a first argument' do
          subject.trap(10) do |signal|
            @buffer << signal
          end

          send_usr1!
          send_usr1!
          wait_signals!

          expect(@buffer).to eq(['USR1', 'USR1'])
        end
      end
    end

    describe 'with two arguments block' do
      it 'passes signal name as a first argument and previous handler as a second' do
        subject.trap('USR1') do |signal, prev|
          @buffer << signal
          @buffer << prev
        end

        send_usr1!
        send_usr1!
        wait_signals!

        expect(@buffer).to eq(['USR1', 'DEFAULT', 'USR1', 'DEFAULT'])
      end

      describe 'with previously defined handler' do
        before { @buffer = [] }

        def usr1_handler
          @buffer << :hello
        end

        include_context 'previously defined USR1'

        it 'is able to call it' do
          subject.trap('USR1') do |signal, prev|
            @buffer << signal
            prev.call
          end

          send_usr1!
          send_usr1!
          wait_signals!

          expect(@buffer).to eq(['USR1', :hello, 'USR1', :hello])
        end
      end
    end
  end

  shared_examples '#untrap behavior' do
    it 'unregisters handler method' do
      subject.trap('USR1') { }
      expect(handlers).to have_key('USR1')
      subject.untrap('USR1')
      expect(handlers).not_to have_key('USR1')
    end

    describe 'when accessing by number' do
      it 'unregisters handler method' do
        subject.trap(10) { }
        expect(handlers).to have_key('USR1')
        subject.untrap(10)
        expect(handlers).not_to have_key('USR1')
      end
    end

    describe 'with previously defined handler' do
      before { @buffer = [] }

      def usr1_handler
        @buffer << :hello
      end

      include_context 'previously defined USR1'

      it 'restores to it' do
        send_usr1!
        send_usr1!
        wait_signals!

        subject.trap('USR1') do
          @buffer << :ehlo
        end

        send_usr1!
        send_usr1!
        wait_signals!

        subject.untrap('USR1')

        send_usr1!
        send_usr1!
        wait_signals!

        expect(@buffer).to eq([:hello, :hello, :ehlo, :ehlo, :hello, :hello])
      end

      describe 'race condition with stale signals in queue' do
        it 'does not happen' do
          subject.trap('USR1') do
            @buffer << :ehlo
            if @buffer.length == 10
              subject.untrap('USR1')
            end
          end

          thread = Thread.new do
            100.times do
              send_usr1!
            end
            wait_signals!
          end

          thread.join

          expect(@buffer[0...10]).to eq([:ehlo]*10)
        end
      end
    end
  end

  describe 'creating instance by .new' do
    subject! { described_class.new }

    describe 'returned object' do
      it { should be_kind_of described_class }
      it { should_not be_started }
    end

    describe '#start!' do
      after { subject.stop! }

      it 'changes `started?` property to true' do
        expect {
          subject.start!
        }.to change(subject, :started?).from(false).to(true)
      end

      it 'increases thread count by 1' do
        expect {
          subject.start!
        }.to change { Thread.list.length }.by(1)
      end
    end

    describe 'when started' do
      before { subject.start! }

      describe '#stop!' do
        include_examples '#stop behavior'
      end

      describe 'trap methods' do
        after { subject.stop! }

        describe '#trap' do
          include_examples '#trap behavior'
        end

        describe '#untrap' do
          include_examples '#untrap behavior'
        end
      end
    end
  end

  describe 'creating instance by .start!' do
    subject! { described_class.start! }

    describe 'returned object' do
      after { subject.stop! }

      it { should be_kind_of described_class }
      it { should be_started }
    end

    describe '#stop!' do
      include_examples '#stop behavior'
    end

    describe 'trap methods' do
      after { subject.stop! }

      describe '#trap' do
        include_examples '#trap behavior'
      end

      describe '#untrap' do
        include_examples '#untrap behavior'
      end
    end
  end

  describe '.start! with block' do
    describe 'yielded object' do
      around do |example|
        described_class.start! do |block_obj|
          @block_obj = block_obj
          example.run
        end
      end
      let(:subject) { @block_obj }

      it { should be_kind_of described_class }
      it { should be_started }

      describe '#trap' do
        include_examples '#trap behavior'
      end

      describe '#untrap' do
        include_examples '#untrap behavior'
      end
    end

    it 'should stop after block termination' do
      obj = nil
      described_class.start! do |block_obj|
        obj = block_obj
      end
      expect(obj).to_not be_started
    end
  end

  describe '.global' do
    subject! { described_class.global }

    describe 'returned object' do
      it { should be_kind_of described_class }
      it { should be_started }
    end

    describe 'when started' do
      before { subject.start! unless subject.started? }

      describe '#stop' do
        include_examples '#stop behavior'
      end

      describe 'trap methods' do
        after { subject.stop! }

        describe '#trap' do
          include_examples '#trap behavior'
        end

        describe '#untrap' do
          include_examples '#untrap behavior'
        end
      end
    end
  end
end
