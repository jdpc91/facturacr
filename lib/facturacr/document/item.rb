module FE
  class Document
    class Item
      include ActiveModel::Validations
      
      attr_accessor :line_number, :code, :commercial_code, :quantity, :unit, :description, :unit_price, :total,
                    :discount, :discount_reason, :subtotal, :taxes, :tax_net, :net_total
                    
      validates :line_number, presence: true
      validates :quantity, presence: true
      validates :unit, presence: true
      validates :description, presence: true, length: {maximum: 200 }
      validates :unit_price, presence: true
      validates :total, presence: true
      validates :discount, numericality: { grater_than: 0}, if: ->{ discount.present? }
      validates :discount_reason, presence: true, if: ->{ discount.present? }
      validates :subtotal, presence: true
      validates :tax_net, presence: true
      validates :net_total, presence: true
      
      
      def initialize(args={})
        @line_number = args[:line_number]
        @code = args[:code]
        @commercial_code = args[:commercial_code]
        @quantity = args[:quantity]
        @unit = args[:unit]
        @description = args[:description]
        @unit_price = args[:unit_price]
        @total = args[:total]
        @discount = args[:discount]
        @discount_reason = args[:discount_reason]
        @subtotal = args[:subtotal]
        @taxes = args[:taxes] || []
        @tax_net = args[:tax_net]
        @net_total = args[:net_total]
      end
      
      def build_xml(node)
        raise "Item invalid: #{errors.messages}" unless valid?
        node = Nokogiri::XML::Builder.new if node.nil?
        node.LineaDetalle do |x|
          x.NumeroLinea @line_number
          x.Codigo @code if @code.present?
          if @commercial_code.present?
            x.CodigoComercial do |x2|
              x2.Tipo "01"
              x2.Codigo @commercial_code
            end
          end
          x.Cantidad @quantity
          x.UnidadMedida @unit
          x.Detalle @description
          x.PrecioUnitario @unit_price
          x.MontoTotal @total
          if @discount.present?
            x.Descuento do |x3|
              x3.MontoDescuento @discount
              x3.NaturalezaDescuento @discount_reason
            end
          end
          x.SubTotal @subtotal
          x.BaseImponible @taxable_base
          @taxes.each do |tax|
            tax.build_xml(x)
          end
          if @exoneration.present?
            @exoneration.build_xml(x)
          end
          x.ImpuestoNeto @tax_net
          x.MontoTotalLinea @net_total
        end
      end
      
    end
  end
end
