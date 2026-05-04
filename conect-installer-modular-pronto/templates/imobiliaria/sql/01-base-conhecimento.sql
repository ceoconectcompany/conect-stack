-- TEMPLATE GENÉRICO - Base de conhecimento para agente imobiliário
-- Rode no SQL Editor do Supabase do cliente.

create table if not exists public.base_conhecimento_imobiliaria (
  id uuid primary key default gen_random_uuid(),
  cliente_id text,
  categoria text not null,
  pergunta text not null,
  resposta text not null,
  palavras_chave text[] default '{}',
  prioridade integer default 1,
  ativo boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_base_conhecimento_cliente on public.base_conhecimento_imobiliaria (cliente_id);
create index if not exists idx_base_conhecimento_categoria on public.base_conhecimento_imobiliaria (categoria);
create index if not exists idx_base_conhecimento_ativo on public.base_conhecimento_imobiliaria (ativo);

-- Exemplos iniciais. Troque CLIENTE_IMOBILIARIA_001 pelo cliente_id do Config Cliente.
insert into public.base_conhecimento_imobiliaria
(cliente_id, categoria, pergunta, resposta, palavras_chave, prioridade, ativo)
values
('CLIENTE_IMOBILIARIA_001', 'HORARIOS', 'Qual é o horário de atendimento?', 'Atendemos de segunda a sexta em horário comercial. Para visitas fora desse horário, consulte a equipe para verificar disponibilidade.', array['horario','abre','fecha','atendimento','sabado','domingo'], 10, true),
('CLIENTE_IMOBILIARIA_001', 'LOCALIZACAO', 'Onde fica a imobiliária?', 'Nosso atendimento é focado em CIDADE_ATENDIDA e região. Para endereço exato e melhor rota, posso te conectar com a equipe.', array['endereco','localizacao','onde fica','rua','mapa'], 10, true),
('CLIENTE_IMOBILIARIA_001', 'SOBRE_NOS', 'Quem é a imobiliária?', 'Somos uma imobiliária especializada em conectar clientes aos imóveis certos com atendimento consultivo, ágil e seguro.', array['sobre','quem sao voces','imobiliaria','empresa'], 8, true),
('CLIENTE_IMOBILIARIA_001', 'DOCUMENTACAO', 'Quais documentos preciso para comprar ou alugar?', 'Normalmente são solicitados documentos pessoais, comprovante de renda e informações do imóvel desejado. A lista exata pode variar conforme compra, financiamento ou locação.', array['documentos','cpf','rg','comprovante','renda'], 8, true),
('CLIENTE_IMOBILIARIA_001', 'FINANCIAMENTO', 'Vocês ajudam com financiamento?', 'Podemos orientar o cliente nos primeiros passos e encaminhar para simulação/análise com os responsáveis. A aprovação depende da análise oficial da instituição financeira.', array['financiamento','financiar','caixa','banco','fgts'], 9, true),
('CLIENTE_IMOBILIARIA_001', 'VISITAS', 'Como agendar visita?', 'Para agendar uma visita, me envie qual imóvel você gostou, melhor dia/horário e seu nome. A equipe confirma a disponibilidade.', array['visita','agendar','conhecer','ver imovel'], 9, true),
('CLIENTE_IMOBILIARIA_001', 'GARANTIAS', 'Quais garantias são aceitas na locação?', 'As garantias podem variar por imóvel. As mais comuns são caução, fiador ou seguro-fiança. A equipe confirma a opção disponível para o imóvel escolhido.', array['garantia','fiador','caucao','seguro fianca','locacao'], 8, true);
