begin;
create function public.create_notice_draft(input jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare bid uuid; source uuid;
begin
 if not is_staff() then raise exception 'Staff access required'; end if;
 if input->>'closing_at' !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' or input->>'next_check_due' !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' then raise exception 'Explicit timezone required'; end if;
 if length(trim(input->>'evidence_reference'))=0 or length(trim(input->>'original_text'))=0 or length(trim(input->>'access_label'))=0 then raise exception 'Evidence and access instructions required'; end if;
 insert into opportunities(buyer,reference,title,category,region,lot,scope,submission_channel,closing_at,original_deadline) values(input->>'buyer',input->>'reference',input->>'title',input->>'category',input->>'region',input->>'lot',input->>'scope',input->>'submission_channel',(input->>'closing_at')::timestamptz,input->>'original_deadline') returning id into bid;
 insert into sources(name,kind,access_instructions,monitoring_schedule) values(input->>'buyer',input->>'kind',input->>'access_label','Unapproved — operations must confirm source rota') returning id into source;
 insert into source_versions(opportunity_id,source_id,version,original_text,evidence_reference,original_url,access_label,checked_at,next_check_due,content_hash) values(bid,source,1,input->>'original_text',input->>'evidence_reference',nullif(input->>'original_url',''),input->>'access_label',now(),(input->>'next_check_due')::timestamptz,md5(input->>'original_text'));
 insert into audit_events(event_type,opportunity_id,details) values('notice_drafted',bid,jsonb_build_object('actor_type','staff'));
 return bid;
end; $$;
create function public.publish_notice(bid uuid) returns void language plpgsql security definer set search_path=public as $$
declare evidence source_versions;
begin
 if not exists(select 1 from staff where user_id=auth.uid() and role in ('reviewer','operations')) then raise exception 'Reviewer access required'; end if;
 perform 1 from opportunities where id=bid and status='draft' for update;
 if not found then raise exception 'Draft not found'; end if;
 select * into evidence from source_versions where opportunity_id=bid order by version desc limit 1;
 if not found then raise exception 'Source evidence required'; end if;
 if evidence.created_by=auth.uid() then raise exception 'A second staff reviewer must publish'; end if;
 if not exists(select 1 from sources where id=evidence.source_id and approved) then raise exception 'Operations must approve source and monitoring schedule first'; end if;
 if evidence.next_check_due <= now() then raise exception 'Source verification is overdue'; end if;
 update opportunities set status='published',reviewed_by=auth.uid(),reviewed_at=now() where id=bid;
 insert into audit_events(event_type,opportunity_id,details) values('notice_published',bid,jsonb_build_object('actor_type','staff','source_version',evidence.version));
end; $$;
revoke all on function create_notice_draft(jsonb),publish_notice(uuid) from public;
grant execute on function create_notice_draft(jsonb),publish_notice(uuid) to authenticated;
commit;
