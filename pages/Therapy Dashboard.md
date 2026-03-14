# Therapy Dashboard
- ## Recent Sessions
  
  #+BEGIN_QUERY
  {:title "Latest Therapy Sessions"
  :query [
   :find (pull ?b [*])
   :where
   [?b :block/properties ?p]
   [(get ?p :type) ?type]
   [(= ?type "therapy-session")]
  ]
  :result-transform (fn [result] (reverse result))
  }
  #+END_QUERY