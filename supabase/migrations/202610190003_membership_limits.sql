begin;
create function public.enforce_seat_limit() returns trigger language plpgsql security definer set search_path=public as $$
begin
 perform 1 from organizations where id=new.organization_id for update;
 if new.revoked_at is null and (select count(*) from memberships where organization_id=new.organization_id and revoked_at is null and user_id<>new.user_id)>=2 then raise exception 'Two active seats allowed in the pilot'; end if;
 return new;
end; $$;
create trigger membership_seat_limit before insert or update on memberships for each row execute function enforce_seat_limit();
-- Changes invalidate comparisons by version without deleting historical assessments.
create function public.bump_profile_version() returns trigger language plpgsql set search_path=public as $$
begin
 if (new.services,new.regions) is distinct from (old.services,old.regions) then new.profile_version=old.profile_version+1; end if;
 return new;
end; $$;
create trigger profile_version before update on organizations for each row execute function bump_profile_version();
commit;
