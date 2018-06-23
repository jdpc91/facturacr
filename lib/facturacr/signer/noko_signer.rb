require 'openssl'
require 'base64'
require "rexml/document"
require "rexml/xpath"

module FE
  class NokoSigner
    C14N            = "http://www.w3.org/TR/2001/REC-xml-c14n-20010315" #"http://www.w3.org/2001/10/xml-exc-c14n#"
    DSIG            = "http://www.w3.org/2000/09/xmldsig#"
    NOKOGIRI_OPTIONS = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET | Nokogiri::XML::ParseOptions::NOENT
    RSA_SHA1        = "http://www.w3.org/2000/09/xmldsig#rsa-sha1"
    RSA_SHA256      = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
    RSA_SHA384      = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha384"
    RSA_SHA512      = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha512"
    SHA1            = "http://www.w3.org/2000/09/xmldsig#sha1"
    SHA256          = "http://www.w3.org/2001/04/xmlenc#sha256"
    SHA384          = "http://www.w3.org/2001/04/xmldsig-more#sha384"
    SHA512          = "http://www.w3.org/2001/04/xmlenc#sha512"
    ENVELOPED_SIG   = "http://www.w3.org/2000/09/xmldsig#enveloped-signature"
    INC_PREFIX_LIST = "#default samlp saml ds xs xsi md"
    NAMESPACES =      "#default ds xs xsi xades xsd"

    XADES           = "http://uri.etsi.org/01903/v1.3.2#"
    XADES141        = "http://uri.etsi.org/01903/v1.4.1#"
    SIGNATURE_POLICY = "https://tribunet.hacienda.go.cr/docs/esquemas/2016/v4/Resolucion%20Comprobantes%20Electronicos%20%20DGT-R-48-2016.pdf"
    
    def initialize(key_path, key_password,input_xml, output_path=nil)
      @doc = File.open(input_xml){ |f| Nokogiri::XML(f)}
      @p12 = OpenSSL::PKCS12.new(File.read("tmp/pruebas.p12"),"8753")
      @x509 = @p12.certificate
      @output_path = output_path
    end
    
    def sign
      #Build parts for Digest Calculation
      key_info = build_key_info_element
      signed_properties = build_signed_properties_element
      signed_info_element = build_signed_info_element(key_info,signed_properties)
      
      # Compute Signature
      signed_info_canon = canonicalize_document(signed_info_element)
      signature_value = compute_signature(@p12.key,algorithm(RSA_SHA256).new,signed_info_canon)
      
      # delete parts namespaces
      #signed_info_element.remove_namespaces!
      #key_info.remove_namespaces!
      #signed_properties.remove_namespaces!
      
      ds = Nokogiri::XML::Node.new("ds:Signature", @doc)
      ds["xmlns:ds"] = DSIG
      ds["Id"] = "xmldsig-#{uuid}"
      ds.add_child(signed_info_element.root)
      
      sv = Nokogiri::XML::Node.new("ds:SignatureValue", @doc)
      sv["Id"] = "xmldsig-#{uuid}-sigvalue"
      sv.content = signature_value
      ds.add_child(sv)
      
      ds.add_child(key_info.root)
      
      
      dsobj = Nokogiri::XML::Node.new("ds:Object",@doc)
      qp = Nokogiri::XML::Node.new("xades:QualifyingProperties",@doc)
      qp["xmlns:xades"] = XADES
      qp["xmlns:xades141"] = XADES141
      qp["Target"] = "#xmldsig-#{uuid}"
      qp.add_child(signed_properties.root)
      
      dsobj.add_child(qp)
      ds.add_child(dsobj)
      @doc.root.add_child(ds)
      
      
      @doc.root.add_child(ds)
      
      File.open(@output_path,"w"){|f| f.write(@doc.to_s)} if @output_path
      
      @doc
    end
    
    def build_key_info_element
      builder  = Nokogiri::XML::Builder.new
      attributes = {
        "xmlns" => "https://tribunet.hacienda.go.cr/docs/esquemas/2017/v4.2/facturaElectronica",
        "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#",
        "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "Id"=>"xmldsig-#{uuid}-keyinfo"
      }
      
      builder.send("ds:KeyInfo", attributes) do |ki|
        ki.send("ds:X509Data") do |kd|
          kd.send("ds:X509Certificate", @x509.to_pem.to_s.gsub("-----BEGIN CERTIFICATE-----","").gsub("-----END CERTIFICATE-----","").gsub(/\n|\r/, ""))
        end
        ki.send("ds:KeyValue") do |kv|
          kv.send("ds:RSAKeyValue") do |rv|
            rv.send("ds:Modulus", Base64.encode64(@x509.public_key.params["n"].to_s(2)).gsub("\n",""))
            rv.send("ds:Exponent", Base64.encode64(@x509.public_key.params["e"].to_s(2)).gsub("\n",""))
          end
        end
      end
      builder.doc
    end
    
    def build_signed_properties_element
      cert_digest = compute_digest(@x509.to_der,algorithm(SHA256))
      policy_digest = compute_digest(@x509.to_der,algorithm(SHA256))
      signing_time = DateTime.now
      builder = builder  = Nokogiri::XML::Builder.new
      attributes = {
        "xmlns"=>"https://tribunet.hacienda.go.cr/docs/esquemas/2017/v4.2/facturaElectronica",
        "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#",
        "xmlns:xades" => "http://uri.etsi.org/01903/v1.3.2#",
        "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
        "xmlns:xades141" => XADES141,
        "Id" => "xmldsig-#{uuid}-signedprops"
      }
      builder.send("xades:SignedProperties", attributes) do |sp|
        sp.send("xades:SigningTime", signing_time.rfc3339)
        sp.send("xades:SigningCertificate") do |sc|
          sc.send("xades:Cert") do |c|
            c.send("ds:DigestMethod", {"Algorithm"=>SHA256})
            c.send("ds:DigestValue", cert_digest)
            c.send("xades:IssuerSerial") do |is|
              is.send("ds:X509IssuerName", @x509.issuer.to_a.reverse.map{|c| c[0..1].join("=")}.join(", "))
              is.send("ds:X509SerialNumber", @x509.serial.to_s)
            end
          end
        end
        sp.send("xades:SignaturePolicyIdentifier") do |spi|
          spi.send("xades:SignaturePolicyId") do |spi2|
            spi2.send("xades:Identifier", SIGNATURE_POLICY)
            spi2.send("xades:SigPolicyHash") do |sph|
              sph.send("ds:DigestMethod", {"Algorithm"=>"http://www.w3.org/2000/09/xmldsig#sha1"})
              sph.send("ds:DigestValue", "V8lVVNGDCPen6VELRD1Ja8HARFk=")
            end
          end
        end
      end
      
      builder.doc
    end
    
    def build_signed_info_element(key_info_element, signed_props_element)
      
      builder = builder  = Nokogiri::XML::Builder.new
      attributes = {
        "xmlns"=>"https://tribunet.hacienda.go.cr/docs/esquemas/2017/v4.2/facturaElectronica",
        "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#",
        "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
      }
      builder.send("ds:SignedInfo", attributes) do |si|
        si.send("ds:CanonicalizationMethod", { "Algorithm"=>C14N })
        si.send("ds:SignatureMethod", {"Algorithm"=>RSA_SHA256})
        
        si.send("ds:Reference",{"Id"=>"xmldsig-#{uuid}-ref0"}) do |r|
          r.send("ds:Transforms") do |t|
            t.send("ds:Transform", {"Algorithm"=>ENVELOPED_SIG})
          end
          r.send("ds:DigestMethod", {"Algorithm"=> SHA256})
          r.send("ds:DigestValue", digest_document(@doc,SHA256))
        end
        
        si.send("ds:Reference",{"URI"=>"#xmldsig-#{uuid}-keyinfo"}) do |r|
          r.send("ds:DigestMethod", {"Algorithm"=> SHA256})
          r.send("ds:DigestValue", digest_document(key_info_element, SHA256, true))
        end
        
        si.send("ds:Reference",{"URI"=>"#xmldsig-#{uuid}-signedprops"}) do |r|
          r.send("ds:DigestMethod", {"Algorithm"=> SHA256})
          r.send("ds:DigestValue", digest_document(signed_props_element, SHA256, true))
        end
      end
      
            
      builder.doc
    end
    
    def digest_document(doc, digest_algorithm=SHA256, strip=false)
      compute_digest(canonicalize_document(doc,strip),algorithm(digest_algorithm))
    end
    
    def canonicalize_document(doc,strip=false)
      #doc = doc.to_s if doc.is_a?(REXML::Element)
      #doc.strip! if strip
      #doc.encode("UTF-8")
      #noko = Nokogiri::XML(doc) do |config|
      #  config.options = NOKOGIRI_OPTIONS
      #end
      
      doc.canonicalize(canon_algorithm(C14N),NAMESPACES.split(" "))
    end
    
    
    def uuid
      @uuid ||= SecureRandom.uuid
    end
    
    def canon_algorithm(element)
     algorithm = element
     

     case algorithm
       when "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
            "http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments"
         Nokogiri::XML::XML_C14N_1_0
       when "http://www.w3.org/2006/12/xml-c14n11",
            "http://www.w3.org/2006/12/xml-c14n11#WithComments"
         Nokogiri::XML::XML_C14N_1_1
       else
         Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0
     end
    end

    def algorithm(element)
     algorithm = element
     if algorithm.is_a?(REXML::Element)
       algorithm = element.attribute("Algorithm").value
     elsif algorithm.is_a?(Nokogiri::XML::Element)
       algorithm = element.xpath("//@Algorithm", "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#").first.value
     end

     algorithm = algorithm && algorithm =~ /(rsa-)?sha(.*?)$/i && $2.to_i

     case algorithm
     when 256 then OpenSSL::Digest::SHA256
     when 384 then OpenSSL::Digest::SHA384
     when 512 then OpenSSL::Digest::SHA512
     else
       OpenSSL::Digest::SHA1
     end
    end

    def compute_signature(private_key, signature_algorithm, document)
      Base64.encode64(private_key.sign(signature_algorithm, document)).gsub(/\n/, "")
    end

    def compute_digest(document, digest_algorithm)
     digest = digest_algorithm.digest(document)
     Base64.encode64(digest).strip!
    end
    
    
    
    
  end
end