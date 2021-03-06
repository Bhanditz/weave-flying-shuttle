RSpec.describe FlyingShuttle::PeerManager do
  let(:weave_client) { double(:weave_client) }
  let(:subject) { described_class.new(weave_client) }

  def build_labeled_node(name, region, external_ip)
    K8s::Resource.new(kind: 'Node', apiVersion: 'v1',
      metadata: {
        name: name,
        labels: {
          'failure-domain.beta.kubernetes.io/region' => region,
          'node-address.kontena.io/external-ip' => external_ip
        }
      },
      status: {
        addresses: [
          { type: 'InternalIP', address: external_ip.sub('192.168', '10.10')}
        ]
      }
    )
  end

  describe '#update_peers' do
    before(:each) do
      allow(subject).to receive(:set_peers)
      allow(subject).to receive(:hostname).and_return('host-01')
    end

    it 'calculates peers correctly' do
      peers = [
        build_labeled_node('host-01', 'eu-west-1', '192.168.100.10'),
        build_labeled_node('host-02', 'eu-west-1', '192.168.100.11'),
        build_labeled_node('host-03', 'eu-central-1', '192.168.100.10')
      ]

      expect(subject).to receive(:set_peers).with([
        '10.10.100.11', '192.168.100.10'
      ].sort)
      subject.update_peers(peers)
    end
  end

  describe '#set_peers' do
    it 'instructs weave about new peers' do
      peers = ['a', 'b']
      response = double(:response, status: 200)
      expect(weave_client).to receive(:post).with(
        hash_including(
          path: '/connect',
          body: 'peer[]=a&peer[]=b&replace=true'
        )
      ).and_return(response)
      expect(subject.set_peers(peers)).to be_truthy
    end

    it 'returns false if peers cannot be set' do
      peers = ['a', 'b']
      response = double(:response, status: 400)
      expect(weave_client).to receive(:post).with(
        hash_including(
          path: '/connect',
          body: 'peer[]=a&peer[]=b&replace=true'
        )
      ).and_return(response)
      expect(subject.set_peers(peers)).to be_falsey
    end
  end
end