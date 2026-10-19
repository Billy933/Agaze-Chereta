begin;
create table public.organizations (id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) > 1), services text not null default '', regions text not null default '', profile_version integer not null default 1, created_at timestamptz not null default now());
create table public.memberships (organization_id uuid references public.organizations on delete cascade, user_id uuid references auth.users on delete cascade, role text not null check(role in ('owner','bid_officer')), revoked_at timestamptz, primary key(organization_id,user_id));
create table public.staff (user_id uuid primary key references auth.users, role text not null check(role in ('analyst','reviewer','operations')));
create function public.is_staff() returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from staff where user_id=auth.uid()); $$;
create function public.is_member(org uuid) returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from memberships where organization_id=org and user_id=auth.uid() and revoked_at is null); $$;
create table public.sources (id uuid primary key default gen_random_uuid(), name text not null, kind text not null check(kind in ('egp','buyer_web','newspaper','direct_submission')), access_instructions text not null, monitoring_schedule text not null, approved boolean not null default false);
create table public.opportunities (id uuid primary key default gen_random_uuid(), buyer text not null, reference text not null, lot text not null default 'Whole notice', rebid text not null default '', title text not null, category text not null check(category in ('Marketing','Media')), region text not null, scope text not null, submission_channel text not null, closing_at timestamptz not null, original_deadline text not null, status text not null default 'draft' check(status in ('draft','review_needed','published','amended','closed','cancelled','archived')), version integer not null default 1, reviewed_by uuid references auth.users, reviewed_at timestamptz, unique(buyer,reference,lot,rebid), check(status not in ('published','amended') or (reviewed_by is not null and reviewed_at is not null)));
create table public.source_versions (id uuid primary key default gen_random_uuid(), opportunity_id uuid not null references public.opportunities, source_id uuid not null references public.sources, version integer not null, original_text text not null, evidence_reference text not null, original_url text check(original_url is null or original_url ~ '^https://'), access_label text not null, checked_at timestamptz not null, next_check_due timestamptz not null, content_hash text not null, created_by uuid not null default auth.uid() references auth.users, unique(opportunity_id,source_id,version));
create table public.assessments (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations, opportunity_id uuid not null references public.opportunities, source_version integer not null, profile_version integer not null, relevance text not null check(relevance in ('high','medium','low')), reasons text not null, coverage_confirmed boolean not null default false, requirements jsonb not null default '[]', reviewed_by uuid not null references auth.users, created_at timestamptz not null default now());
create table public.saved_bids (organization_id uuid references public.organizations, opportunity_id uuid references public.opportunities, stage text not null check(stage in ('saved','pursuing','declined','submitted','outcome_recorded')), reason text not null default '', notes text not null default '', assessment_id uuid references public.assessments, updated_at timestamptz not null default now(), primary key(organization_id,opportunity_id), check(stage <> 'declined' or length(trim(reason)) > 0));
create table public.audit_events (id uuid primary key default gen_random_uuid(), organization_id uuid references public.organizations, actor_id uuid not null default auth.uid(), event_type text not null, opportunity_id uuid references public.opportunities, assessment_id uuid references public.assessments, details jsonb not null default '{}', created_at timestamptz not null default now());
create table public.notification_outbox (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations, recipient_id uuid not null references auth.users, opportunity_id uuid not null references public.opportunities, event_type text not null, semantic_event_version text not null, occurrence_id uuid not null, channel text not null check(channel in ('email','sms')), payload jsonb not null, payload_hash text not null, state text not null default 'held' check(state in ('held','queued','acceptance_unknown','accepted','delivered','suppressed','failed')), suppression_reason text, verified_at timestamptz not null, committed_at timestamptz not null default now(), run_at timestamptz not null, unique(organization_id,recipient_id,opportunity_id,event_type,semantic_event_version,occurrence_id,channel));
create function public.create_company(company_name text, company_services text, company_regions text) returns uuid language plpgsql security definer set search_path=public as $$
declare org uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if exists(select 1 from memberships where user_id=auth.uid() and revoked_at is null) then raise exception 'You already have a company'; end if;
 insert into organizations(name,services,regions) values(company_name,company_services,company_regions) returning id into org;
 insert into memberships values(org,auth.uid(),'owner',null);
 return org;
end; $$;
create function public.record_decision(org uuid, bid uuid, new_stage text, decision_reason text, decision_notes text, assessment uuid default null, acknowledge_outdated boolean default false) returns void language plpgsql security definer set search_path=public as $$
declare previous text; a assessments; o opportunities;
begin
 if not is_member(org) then raise exception 'Access denied'; end if;
 perform 1 from organizations where id=org for update;
 select * into o from opportunities where id=bid and status in ('published','amended','closed','cancelled');
 if not found then raise exception 'Notice unavailable'; end if;
 select stage into previous from saved_bids where organization_id=org and opportunity_id=bid;
 if new_stage in ('saved','pursuing') and coalesce(previous,'') not in ('saved','pursuing') and (select count(*) from saved_bids where organization_id=org and stage in ('saved','pursuing')) >= 5 then raise exception 'Five active saved bids allowed'; end if;
 if new_stage in ('pursuing','submitted') and (o.status in ('closed','cancelled') or o.closing_at<=now()) then raise exception 'This bid is no longer open'; end if;
 if assessment is not null then
  select * into a from assessments where id=assessment and organization_id=org and opportunity_id=bid;
  if not found then raise exception 'Assessment does not belong to this bid and company'; end if;
  if (a.source_version<>o.version or a.profile_version<>(select profile_version from organizations where id=org)) and not acknowledge_outdated then raise exception 'Acknowledge outdated assessment'; end if;
 end if;
 insert into saved_bids values(org,bid,new_stage,decision_reason,decision_notes,assessment,now()) on conflict(organization_id,opportunity_id) do update set stage=excluded.stage,reason=excluded.reason,notes=excluded.notes,assessment_id=excluded.assessment_id,updated_at=now();
 if previous is distinct from new_stage then insert into audit_events(organization_id,event_type,opportunity_id,assessment_id,details) values(org,'tracker_transition',bid,assessment,jsonb_build_object('actor_type','customer','prior_stage',previous,'new_stage',new_stage,'reason',decision_reason,'acknowledged_outdated',acknowledge_outdated)); end if;
end; $$;
-- No client can grant staff access, change membership, publish directly, or dispatch messages.
alter table organizations enable row level security;
alter table memberships enable row level security;
alter table staff enable row level security;
alter table sources enable row level security;
alter table opportunities enable row level security;
alter table source_versions enable row level security;
alter table assessments enable row level security;
alter table saved_bids enable row level security;
alter table audit_events enable row level security;
alter table notification_outbox enable row level security;
create policy own_org on organizations for select to authenticated using(is_member(id));
create policy own_membership on memberships for select to authenticated using(is_member(organization_id));
create policy source_read on sources for select to authenticated using(approved or is_staff());
create policy notice_read on opportunities for select to authenticated using(status in ('published','amended','closed','cancelled') or is_staff());
create policy evidence_read on source_versions for select to authenticated using(exists(select 1 from opportunities o where o.id=opportunity_id));
create policy assessment_read on assessments for select to authenticated using(is_member(organization_id));
create policy saved_read on saved_bids for select to authenticated using(is_member(organization_id));
create policy audit_read on audit_events for select to authenticated using(is_member(organization_id));
create policy own_brief_view on audit_events for insert to authenticated with check(is_member(organization_id) and actor_id=auth.uid() and event_type='brief_viewed' and exists(select 1 from assessments a where a.id=assessment_id and a.organization_id=audit_events.organization_id and a.opportunity_id=audit_events.opportunity_id));
revoke all on all tables in schema public from anon;
grant select on organizations,memberships,sources,opportunities,source_versions,assessments,saved_bids,audit_events to authenticated;
grant insert on audit_events to authenticated;
revoke all on function create_company(text,text,text),record_decision(uuid,uuid,text,text,text,uuid,boolean) from public;
grant execute on function create_company(text,text,text),record_decision(uuid,uuid,text,text,text,uuid,boolean) to authenticated;
commit;
