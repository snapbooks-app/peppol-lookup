#!/usr/bin/env clojure

;; PEPPOL uses two key services to enable document exchange:
;;
;; 1. SML (Service Metadata Locator):
;;    - Acts as a DNS-based directory service
;;    - Maps a participant's ID to their SMP provider
;;    - Uses DNS lookup to find where a participant's metadata is hosted
;;    - Similar to how email's MX records help find mail servers
;;
;; 2. SMP (Service Metadata Publisher):
;;    - Hosts metadata about a participant's capabilities
;;    - Tells you what document types they can receive
;;    - Provides technical details needed for sending documents
;;    - Acts like a participant's business card in the network
;;
;; This example demonstrates how to:
;; 1. Use SML to find where a participant's metadata is hosted
;; 2. Query their SMP to discover what documents they can receive
;; 3. Check for PEPPOL BIS Billing 3.0 support

(import '(java.net InetAddress UnknownHostException URL URLEncoder URLDecoder)
        '(java.security MessageDigest))

;; Test environment SML domain
(def sml-domain "edelivery.tech.ec.europa.eu")

;; PEPPOL BIS Billing 3.0 document identifiers
(def bis-billing-invoice "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice")
(def bis-billing-creditnote "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote")

;; Helper function to convert bytes to hex string
(defn bytes-to-hex [bytes]
  (apply str (map #(format "%02x" %) bytes)))

;; Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
;;
;; The SML is like a phone book for the PEPPOL network. Given a participant's ID:
;; 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
;; 2. Use the hash to construct a DNS hostname
;; 3. If the hostname exists, the participant is registered in PEPPOL
;; 4. The hostname tells us where to find their metadata (SMP)
;;
;; Returns the SMP hostname if found, nil if not found
(defn sml-lookup [icd identifier]
  (try
    ;; Create MD5 hash of participant ID
    (let [participant-id (str icd ":" identifier)
          md5 (MessageDigest/getInstance "MD5")
          hash-bytes (.digest md5 (.getBytes participant-id))
          md5-hash (bytes-to-hex hash-bytes)

          ;; Construct hostname
          hostname (str "b-" md5-hash ".iso6523-actorid-upis." sml-domain)]

      ;; Check if hostname exists
      (InetAddress/getByName hostname)
      hostname)
    (catch UnknownHostException _ nil)))

;; Step 2: Query SMP (Service Metadata Publisher) to get supported document types
;;
;; The SMP is like a business card in the PEPPOL network. It tells us:
;; 1. What types of documents the participant can receive
;; 2. Technical details needed for sending documents
;; 3. Specific document format versions they support
;;
;; This is similar to how DNS MX records tell you where to send email,
;; but SMP also includes what "types" of messages you can send.
(defn smp-lookup [smp-hostname icd identifier]
  ;; Construct SMP URL
  ;; Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
  (let [participant-id (str icd ":" identifier)
        encoded-id (URLEncoder/encode participant-id "UTF-8")
        url-str (str "http://" smp-hostname "/iso6523-actorid-upis::" encoded-id)
        url (URL. url-str)]

    ;; Perform HTTP GET request
    (with-open [stream (.openStream url)]
      (let [response (slurp stream)

            ;; Extract document types from ServiceMetadataReference href attributes
            pattern #"ServiceMetadataReference[^>]*href=\"([^\"]*)\"[^>]*>"
            matches (re-seq pattern response)]

        (->> matches
             (map second)
             (map #(URLDecoder/decode % "UTF-8"))
             (filter #(re-find #"busdox-docid-qns::" %))
             (map #(second (clojure.string/split % #"busdox-docid-qns::")))
             (map #(first (clojure.string/split % #"#")))
             (vec))))))

;; Main execution
(defn -main []
  (try
    ;; Snapbooks AS (Norwegian organization number)
    (let [icd "0192"
          identifier "921605900"]

      ;; Step 1: Use SML to find where participant's metadata is hosted
      (if-let [smp-hostname (sml-lookup icd identifier)]
        (do
          (println (str "SMP hostname: " smp-hostname))

          ;; Step 2: Query their SMP to discover supported documents
          (let [document-types (smp-lookup smp-hostname icd identifier)]
            (println "\nSupported document identifiers:")
            (doseq [doc-type document-types]
              (println (str "- " doc-type)))

            ;; Check for PEPPOL BIS Billing 3.0 documents
            (println "\nPEPPOL BIS Billing 3.0 Support:")
            (when (some #{bis-billing-invoice} document-types)
              (println "- Supports Invoice"))
            (when (some #{bis-billing-creditnote} document-types)
              (println "- Supports Credit Note"))))

        (do
          (println (str "Not a PEPPOL participant: " icd ":" identifier))
          (System/exit 1))))

    (catch Exception e
      (binding [*out* *err*]
        (println (str "Error: " (.getMessage e))))
      (System/exit 1))))

;; Run main
(-main)
