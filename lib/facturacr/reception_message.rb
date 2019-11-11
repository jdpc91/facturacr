require 'active_model'

module FE
  class ReceptionMessage
    include ActiveModel::Validations
    
    MESSAGE_TYPES = {
      "1" => "Aceptado",
      "2" => "Aceptacion Parcial",
      "3" => "Rechazado"
    }    
    
    TAX_CONDITIONS = {
      "01" => "Genera crédito IVA",
      "02" => "Genera Crédito parcial del IVA",
      "03" => "Bienes de Capital",
      "04" => "Gasto corriente no genera crédito",
      "05" => "Proporcionalidad"
    }
    
    attr_accessor :key, :date, :issuer_id_number, :receiver_id_number, :message, :details, :economicActivity, :taxCondition, :totalAmountTaxCredit, :totalAmountApplicable, :tax, :total, :number, :receiver_id_type, :security_code, :document_situation, :issuer_id_type
    
    validates :date, presence: true
    validates :issuer_id_number, presence: true, length: {in: 9..12}
    validates :receiver_id_number, presence: true, length: {in: 9..12}
    validates :message, presence: true, inclusion: MESSAGE_TYPES.keys
    validates :details, length: {maximum: 160}, if: -> { message == "3" }
    validates :taxCondition, inclusion: TAX_CONDITIONS.keys
    validates :tax, numericality: true, if: -> { tax.present? }
    validates :totalAmountTaxCredit, numericality: true
    validates :totalAmountApplicable, numericality: true
    validates :total, presence: true, numericality: true
    validates :number, presence: true
    #validates :security_code, presence: true, length: {is: 8}
    #validates :issuer_id_type, presence: true
    #validates :receiver_id_type, presence: true
    
    def initialize(args = {})
      @key = args[:key]
      @date = args[:date]
      @issuer_id_type = args[:issuer_id_type]
      @issuer_id_number = args[:issuer_id_number]
      @receiver_id_type = args[:receiver_id_type]
      @receiver_id_number = args[:receiver_id_number]
      @message = args[:message].to_s
      @details = args[:details]
      @economicActivity = args[:economicActivity]
      @taxCondition = args[:taxCondition]
      @totalAmountTaxCredit = args[:totalAmountTaxCredit]
      @totalAmountApplicable = args[:totalAmountApplicable]
      @tax = args[:tax]
      @total = args[:total]
      @number = args[:number].to_i
      @security_code = args[:security_code]
      @document_situation = args[:document_situation]
      @namespaces = {
        "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", 
        "xmlns:xsd"=>"http://www.w3.org/2001/XMLSchema",
        "xmlns"=>"https://cdn.comprobanteselectronicos.go.cr/xml-schemas/v4.3/mensajeReceptor"
      }
    end
    
    
    def headquarters
      @headquarters ||= "001"
    end
  
    def terminal
      @terminal ||= "00001"
    end 
    
    def sequence
      if @message.eql?("1")
        @document_type = "05"
      elsif @message.eql?("2")
        @document_type = "06"
      elsif @message.eql?("3")
        @document_type = "07"
      end
      cons = ("%010d" % @number)
      "#{headquarters}#{terminal}#{@document_type}#{cons}"
    end
    
    
    
    def build_xml
      raise "Documento inválido: #{errors.messages}" unless valid?
      builder  = Nokogiri::XML::Builder.new
      
      builder.MensajeReceptor(@namespaces) do |xml|
        xml.Clave @key
        xml.NumeroCedulaEmisor @issuer_id_number
        xml.FechaEmisionDoc @date.xmlschema
        xml.Mensaje @message
        xml.DetalleMensaje @details if @details.present?
        xml.CodigoActividad @economicActivity if @economicActivity.present? 
        xml.CondicionImpuesto @taxCondition if @taxCondition.present?
        xml.MontoTotalImpuestoAcreditar @totalAmountTaxCredit if @totalAmountTaxCredit.present?
        xml.MontoTotalDeGastoAplicable @totalAmountApplicable if @totalAmountApplicable.present?
        xml.MontoTotalImpuesto @tax.to_f
        xml.TotalFactura @total
        xml.NumeroCedulaReceptor @receiver_id_number
        xml.NumeroConsecutivoReceptor sequence
      end
      
      builder
    end
    
    def generate
      build_xml.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
    end
    
    def api_payload
      
      payload = {}
      payload[:clave] = @key
      payload[:fecha] = @date.xmlschema
      payload[:emisor] = {
        tipoIdentificacion: infer_id_type(@issuer_id_number),
        numeroIdentificacion: @issuer_id_number
      }
      payload[:receptor] = {
        tipoIdentificacion: infer_id_type(@receiver_id_number),
        numeroIdentificacion: @receiver_id_number
      }
      payload[:consecutivoReceptor] = sequence
      payload
    end
    
    def infer_id_type(id_number)
      if id_number.to_i.to_s.size == 9
        "01"
      elsif id_number.to_i.to_s.size == 10
        "02"
      elsif id_number.to_i.to_s.size == 11
        "03"
      end
    end
    
  end
  
end
