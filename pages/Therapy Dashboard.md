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
- ## Key Insights
  
  #+BEGIN_QUERY
  {:title "Therapy Insights"
  :query [
   :find (pull ?b [*])
   :where
   [?b :block/content ?c]
   [(clojure.string/includes? ?c "Insight")]
  ]
  }
  #+END_QUERY
-