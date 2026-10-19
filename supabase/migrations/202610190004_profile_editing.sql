begin;

-- Keep declarations as history; an edit never rewrites analyst findings.
create table public.company_profile_history (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations,
 profile_version integer not null,
 name text not null,
 services text not null,
 regions text not null,
 recorded_by uuid references auth.users,
 recorded_at timestamptz not null default now(),
 unique(organization_id,profile_version)
);
insert into public.company_profile_history(organization_id,profile_version,name,services,regions)
 select id,profile_version,name,services,regions from public.organizations;
alter table public.company_profile_history enable row level security;
create policy profile_history_read on public.company_profile_history for select to authenticated
 using(public.is_member(organization_id));
revoke all on public.company_profile_history from anon,authenticated;
grant select on public.company_profile_history to authenticated;

create function public.record_initial_company_profile() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into company_profile_history(organization_id,profile_version,name,services,regions,recorded_by)
 values(new.id,new.profile_version,new.name,new.services,new.regions,auth.uid());
 return new;
end; $$;
revoke all on function public.record_initial_company_profile() from public;
create trigger initial_company_profile after insert on public.organizations
 for each row execute function public.record_initial_company_profile();

create function public.update_company_profile(org uuid, expected_version integer, company_name text, company_services text, company_regions text)
returns void language plpgsql security definer set search_path=public as $$
declare prior organizations; updated organizations;
begin
 select * into prior from organizations where id=org for update;
 if not found or not exists(select 1 from memberships where organization_id=org and user_id=auth.uid() and role='owner' and revoked_at is null) then
  raise exception 'Only the active company owner can edit this profile';
 end if;
 if prior.profile_version<>expected_version then raise exception 'The profile has changed. Reload before saving your changes'; end if;
 if company_name is null or length(trim(company_name))<2 or length(company_name)>200
    or company_services is null or length(trim(company_services))=0 or length(company_services)>4000
    or company_regions is null or length(trim(company_regions))=0 or length(company_regions)>1000 then
  raise exception 'Provide a company name, services and operating regions within the allowed lengths';
 end if;
 if (prior.name,prior.services,prior.regions) is not distinct from (trim(company_name),trim(company_services),trim(company_regions)) then return; end if;
 update organizations set name=trim(company_name),services=trim(company_services),regions=trim(company_regions),profile_version=prior.profile_version+1 where id=org returning * into updated;
 insert into company_profile_history(organization_id,profile_version,name,services,regions,recorded_by)
 values(org,updated.profile_version,updated.name,updated.services,updated.regions,auth.uid());
 insert into audit_events(organization_id,event_type,details)
 values(org,'company_profile_updated',jsonb_build_object('actor_type','customer','prior_version',prior.profile_version,'profile_version',updated.profile_version));
end; $$;
revoke all on function public.update_company_profile(uuid,integer,text,text,text) from public;
grant execute on function public.update_company_profile(uuid,integer,text,text,text) to authenticated;
commit;
