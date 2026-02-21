import gleamlog/knowledge_base
import gleamlog/types.{type Clause, type KnowledgeBase, type Term}

pub fn asserta(kb: KnowledgeBase, clause: Clause) -> Result(KnowledgeBase, Nil) {
  knowledge_base.asserta(kb, clause)
}

pub fn assertz(kb: KnowledgeBase, clause: Clause) -> Result(KnowledgeBase, Nil) {
  knowledge_base.assertz(kb, clause)
}

pub fn retract(
  kb: KnowledgeBase,
  head: Term,
) -> Result(#(Clause, KnowledgeBase), Nil) {
  knowledge_base.retract(kb, head)
}
