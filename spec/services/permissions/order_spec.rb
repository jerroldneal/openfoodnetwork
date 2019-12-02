require 'spec_helper'

module Permissions
  describe Order do
    let(:user) { double(:user) }
    let(:permissions) { Permissions::Order.new(user) }
    let!(:basic_permissions) { OpenFoodNetwork::Permissions.new(user) }

    before { allow(OpenFoodNetwork::Permissions).to receive(:new) { basic_permissions } }

    describe "finding orders that are visible in reports" do
      let(:distributor) { create(:distributor_enterprise) }
      let(:coordinator) { create(:distributor_enterprise) }
      let(:random_enterprise) { create(:distributor_enterprise) }
      let(:order_cycle) { create(:simple_order_cycle, coordinator: coordinator, distributors: [distributor]) }
      let(:order) { create(:order, order_cycle: order_cycle, distributor: distributor ) }
      let!(:line_item) { create(:line_item, order: order) }
      let!(:producer) { create(:supplier_enterprise) }

      before do
        allow(basic_permissions).to receive(:coordinated_order_cycles) { Enterprise.where("1=0") }
      end

      context "as the hub through which the order was placed" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: distributor) }
        end

        it "should let me see the order" do
          expect(permissions.visible_orders).to include order
        end
      end

      context "as the coordinator of the order cycle through which the order was placed" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: coordinator) }
          allow(basic_permissions).to receive(:coordinated_order_cycles) { OrderCycle.where(id: order_cycle) }
        end

        it "should let me see the order" do
          expect(permissions.visible_orders).to include order
        end
      end

      context "as a producer which has granted P-OC to the distributor of an order" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: producer) }
          create(:enterprise_relationship, parent: producer, child: distributor, permissions_list: [:add_to_order_cycle])
        end

        context "which contains my products" do
          before do
            line_item.product.supplier = producer
            line_item.product.save
          end

          it "should let me see the order" do
            expect(permissions.visible_orders).to include order
          end
        end

        context "which does not contain my products" do
          it "should not let me see the order" do
            expect(permissions.visible_orders).to_not include order
          end
        end
      end

      context "as an enterprise that is a distributor in the order cycle, but not the distributor of the order" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: random_enterprise) }
        end

        it "should not let me see the order" do
          expect(permissions.visible_orders).to_not include order
        end
      end
    end

    describe "finding line items that are visible in reports" do
      let(:distributor) { create(:distributor_enterprise) }
      let(:coordinator) { create(:distributor_enterprise) }
      let(:random_enterprise) { create(:distributor_enterprise) }
      let(:order_cycle) { create(:simple_order_cycle, coordinator: coordinator, distributors: [distributor]) }
      let(:order) { create(:order, order_cycle: order_cycle, distributor: distributor ) }
      let!(:line_item1) { create(:line_item, order: order) }
      let!(:line_item2) { create(:line_item, order: order) }
      let!(:producer) { create(:supplier_enterprise) }

      before do
        allow(basic_permissions).to receive(:coordinated_order_cycles) { Enterprise.where("1=0") }
      end

      context "as the hub through which the parent order was placed" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: distributor) }
        end

        it "should let me see the line_items" do
          expect(permissions.visible_line_items).to include line_item1, line_item2
        end
      end

      context "as the coordinator of the order cycle through which the parent order was placed" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: coordinator) }
          allow(basic_permissions).to receive(:coordinated_order_cycles) { OrderCycle.where(id: order_cycle) }
        end

        it "should let me see the line_items" do
          expect(permissions.visible_line_items).to include line_item1, line_item2
        end
      end

      context "as the manager producer which has granted P-OC to the distributor of the parent order" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: producer) }
          create(:enterprise_relationship, parent: producer, child: distributor, permissions_list: [:add_to_order_cycle])

          line_item1.product.supplier = producer
          line_item1.product.save
        end

        it "should let me see the line_items pertaining to variants I produce" do
          ps = permissions.visible_line_items
          expect(ps).to include line_item1
          expect(ps).to_not include line_item2
        end
      end

      context "as an enterprise that is a distributor in the order cycle, but not the distributor of the parent order" do
        before do
          allow(basic_permissions).to receive(:managed_enterprises) { Enterprise.where(id: random_enterprise) }
        end

        it "should not let me see the line_items" do
          expect(permissions.visible_line_items).to_not include line_item1, line_item2
        end
      end
    end
  end
end
