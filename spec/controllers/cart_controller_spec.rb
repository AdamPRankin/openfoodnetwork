require 'spec_helper'

describe CartController, type: :controller do
  let(:order) { create(:order) }

  describe "returning stock levels in JSON on success" do
    let(:product) { create(:simple_product) }

    it "returns stock levels as JSON" do
      allow(controller).to receive(:variant_ids_in) { [123] }
      allow(VariantsStockLevels).to receive(:new).and_return(variant_stock_levels = double())
      allow(variant_stock_levels).to receive(:call) { 'my_stock_levels' }
      allow(CartService).to receive(:new).and_return(cart_service = double())
      allow(cart_service).to receive(:populate) { true }
      allow(cart_service).to receive(:variants_h) { {} }

      xhr :post, :populate, use_route: :spree, format: :json

      data = JSON.parse(response.body)
      expect(data['stock_levels']).to eq('my_stock_levels')
    end

    it "extracts variant ids from the cart service" do
      variants_h = [{:variant_id=>"900", :quantity=>2, :max_quantity=>nil},
       {:variant_id=>"940", :quantity=>3, :max_quantity=>3}]

      expect(controller.variant_ids_in(variants_h)).to eq([900, 940])
    end
  end

  context "adding a group buy product to the cart" do
    it "sets a variant attribute for the max quantity" do
      distributor_product = create(:distributor_enterprise)
      p = create(:product, :distributors => [distributor_product], :group_buy => true)

      order = subject.current_order(true)
      allow(order).to receive(:distributor) { distributor_product }
      expect(order).to receive(:set_variant_attributes).with(p.master, {'max_quantity' => '3'})
      allow(controller).to receive(:current_order).and_return(order)

      expect do
        spree_post :populate, variants: { p.master.id => 1 }, variant_attributes: { p.master.id => {max_quantity: 3 } }
      end.to change(Spree::LineItem, :count).by(1)
    end

    it "returns HTTP success when successful" do
      allow(CartService).to receive(:new).and_return(cart_service = double())
      allow(cart_service).to receive(:populate) { true }
      allow(cart_service).to receive(:variants_h) { {} }
      xhr :post, :populate, use_route: :spree, format: :json
      expect(response.status).to eq(200)
    end

    it "returns failure when unsuccessful" do
      allow(CartService).to receive(:new).and_return(cart_service = double())
      allow(cart_service).to receive(:populate).and_return false
      xhr :post, :populate, use_route: :spree, format: :json
      expect(response.status).to eq(412)
    end

    it "tells cart_service to overwrite" do
      allow(CartService).to receive(:new).and_return(cart_service = double())
      expect(cart_service).to receive(:populate).with({}, true)
      xhr :post, :populate, use_route: :spree, format: :json
    end
  end
end
