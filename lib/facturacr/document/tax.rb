module FE
  class Document
    class Tax
      include ActiveModel::Validations
      
      TAX_CODES = {
        "01"=>"Impuesto al Valor Agregado",
        "02"=>"Impuesto Selectivo de Consumo",
        "03"=>"Impuesto Único a los Combustibles",
        "04"=>"Impuesto específico de Bebidas Alcohólicas",
        "05"=>"Impuesto Específico sobre las bebidas envasadas sin contenido alcohólico y jabones de tocador",
        "06"=>"Impuesto a los Productos de Tabaco",
        "07"=>"IVA (cálculo especial)",
        "08"=>"IVA Régimen de Bienes Usados (Factor)",
        "12"=>"Impuesto Específico al Cemento",
        "99"=>"Otros"
      }
      RATE_CODES = {
        "01" => "Tarifa 0% (Exento)",
        "02" => "Tarifa reducida 1%",
        "03" => "Tarifa reducida 2%",
        "04" => "Tarifa reducida 4%",
        "05" => "Transitorio 0%",
        "06" => "Transitorio 4%",
        "07" => "Transitorio 8%",
        "08" => "Tarifa general 13%"
      }
      attr_accessor :code, :rate_code, :rate, :tax_factor, :total, :exoneration
      
      validates :code, presence: true, inclusion: TAX_CODES.keys
      validates :rate_code, presence: true, inclusion: RATE_CODES.keys, if: ->{code.eql?("01") || code.eql?("02")}
      validates :tax_factor, presence: true, if: ->{code.eql?("08")}
      
      def initialize(args={})
        @code = args[:code]
        @rate_code = args[:rate_code]
        @rate = args[:rate]
        @tax_factor = args[:tax_factor]
        @total = args[:total]
        @exoneration = args[:exoneration]
      end
      
      def build_xml(node)
        raise "Invalida Record: #{errors.messages}" unless valid?
        node = Nokogiri::XML::Builder.new if node.nil?
        
        node.Impuesto do |xml|
          xml.Codigo @code
          xml.CodigoTarifa @rate_code if @rate_code.present?
          xml.Tarifa @rate
          xml.FactorIVA @tax_factor if @tax_factor.present?
          xml.Monto @total
          if @exoneration.present?
            @exoneration.build_xml(xml)
          end
        end
      end
      
    end
  end
end
