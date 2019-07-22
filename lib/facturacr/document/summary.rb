module FE
  class Document
    class Summary
      include ActiveModel::Validations
      
      attr_accessor :currency, :exchange_rate, :services_taxable_total, :services_exent_total, 
                    :goods_taxable_total,:goods_exent_total, :taxable_total, :exent_total,
                    :subtotal, :discount_total, :gross_total, :tax_total, :net_total
      
      validates :exchange_rate, presence: true, if: -> { currency.present? }
      
      validate :totals_ok?
                    
      def initialize(args={})
        @currency = args[:currency]
        @exchange_rate = args[:exchange_rate]
        @services_taxable_total = args[:services_taxable_total].to_f
        @services_exent_total = args[:services_exent_total].to_f
        @services_exone_total = args[:services_exone_total].to_f
        @goods_taxable_total = args[:goods_taxable_total].to_f
        @goods_exent_total = args[:goods_exent_total].to_f
        @goods_exone_total = args[:goods_exone_total].to_f
        @taxable_total = args[:taxable_total].to_f
        @exent_total = args[:exent_total].to_f
        @exone_total = args[:exone_total].to_f
        @subtotal = args[:subtotal].to_f
        @discount_total = args[:discount_total].to_f
        @gross_total = args[:gross_total].to_f
        @tax_total = args[:tax_total].to_f
        @vat_returned = args[:vat_returned].to_f
        @other_charges_total = args[:other_charges_total].to_f
        @net_total = args[:net_total].to_f
      end
      
      def build_xml(node)
        unless valid?
          raise "Summary invalid: #{errors.messages}" 
        end        
        node = Nokogiri::XML::Builder.new if node.nil?
        
        node.ResumenFactura do |xml|
          if @currency.present?
            xml.CodigoTipoMoneda do |x3|
              x3.CodigoMoneda @currency
              x3.TipoCambio @exchange_rate
            end
          end
          xml.TotalServGravados @services_taxable_total
          xml.TotalServExentos @services_exent_total
          xml.TotalServExonerado @services_exone_total
          xml.TotalMercanciasGravadas @goods_taxable_total
          xml.TotalMercanciasExentas @goods_exent_total
          xml.TotalMercExonerada @goods_exone_total
          xml.TotalGravado @taxable_total
          xml.TotalExento @exent_total
          xml.TotalExonerado @exone_total
          xml.TotalVenta @subtotal
          xml.TotalDescuentos @discount_total
          xml.TotalVentaNeta @gross_total
          xml.TotalImpuesto @tax_total
          xml.TotalIVADevuelto @vat_returned
          xml.TotalOtrosCargos @other_charges_total
          xml.TotalComprobante @net_total
        end
      end
      
      private
      
      def totals_ok?
        errors[:taxable_total] << "invalid amount" unless @taxable_total == (@services_taxable_total + @goods_taxable_total).round(5)
        errors[:exent_total] << "invalid amount" unless @exent_total == (@services_exent_total + @goods_exent_total).round(5)
        errors[:exent_total] << "invalid amount" unless @exone_total == (@services_exone_total + @goods_exone_total).round(5)
        errors[:subtotal] << "invalid amount" unless @subtotal == (@taxable_total + @exent_total + @exone_total).round(5)
        errors[:gross_total] << "invalid amount" unless @gross_total == (@subtotal - @discount_total).round(5)
        errors[:net_total] << "invalid amount" unless @net_total == (@gross_total + @tax_total + @other_charges_total - @VAT_returned).round(5)
      end
    end
  end
end
