'use client';

import { useEffect, useState } from 'react';
import { database } from '../lib/supabase';

type Company = { id: string; name: string; services: string; regions: string; profile_version: number };
type Revision = Company & { recorded_at: string };

export function CompanyProfile({ company, busy, run, reload }: {
 company: Company; busy: boolean; run: (action: () => Promise<void>) => Promise<void>; reload: () => Promise<void>;
}) {
 const [owner, setOwner] = useState(false);
 const [history, setHistory] = useState<Revision[]>([]);
 const [error, setError] = useState('');
 const [saved, setSaved] = useState(false);
 useEffect(() => {
  let active = true;
  setOwner(false); setHistory([]); setError('');
  async function load() {
   try {
    const db = database();
    const { data: { user } } = await db.auth.getUser();
    if (!user) return;
    const [membership, revisions] = await Promise.all([
     db.from('memberships').select('role').eq('organization_id', company.id).eq('user_id', user.id).is('revoked_at', null).maybeSingle(),
     db.from('company_profile_history').select('*').eq('organization_id', company.id).order('profile_version', { ascending: false }).limit(10),
    ]);
    if (!active) return;
    if (membership.error) throw membership.error;
    setOwner(membership.data?.role === 'owner');
    if (revisions.error) throw new Error('Profile history is unavailable. The profile editing database migration may still need to be applied.');
    setHistory(revisions.data ?? []);
   } catch (e) { if (active) setError(e instanceof Error ? e.message : 'Unable to load profile history.'); }
  }
  void load();
  return () => { active = false; };
 }, [company.id, company.profile_version]);

 return <><p className="eyebrow">YOUR COMPANY</p><h1>{company.name}</h1>
  <section className="panel auth"><h2>Company declarations</h2>
   <p>Keep your capabilities and operating regions current. Saving a change creates a new profile version. Earlier assessments remain in history and require review against the new version.</p>
   <span className="pill">Profile version {company.profile_version} · Company declaration</span>
   {error && <p role="alert">{error}</p>}
   {saved && <p role="status">Profile saved. Earlier assessments now require review.</p>}
   <form key={`${company.id}:${company.profile_version}`} onSubmit={event => {
    event.preventDefault(); const form = new FormData(event.currentTarget); setSaved(false);
    void run(async () => {
     const { error } = await database().rpc('update_company_profile', {
      org: company.id, expected_version: company.profile_version,
      company_name: form.get('name'), company_services: form.get('services'), company_regions: form.get('regions'),
     });
     if (error) throw error;
     await reload(); setSaved(true);
    });
   }}>
    <label>Company name<input name="name" defaultValue={company.name} required minLength={2} maxLength={200} readOnly={!owner}/></label>
    <label>Services and capabilities<textarea name="services" defaultValue={company.services} required maxLength={4000} readOnly={!owner}/></label>
    <label>Operating regions<textarea name="regions" defaultValue={company.regions} required maxLength={1000} readOnly={!owner}/></label>
    {owner ? <button className="primary" disabled={busy || !!error}>Save profile</button> : <p>The company owner can edit these declarations.</p>}
   </form>
   <p>Declarations do not establish eligibility. Analyst verification and evidence references are required before they can support screening.</p>
  </section>
  <section className="panel"><h2>Profile history</h2><p>Latest ten versions, including the starting snapshot recorded when profile history was enabled.</p>
   {history.length ? history.map(revision => <details className="source" key={revision.profile_version}>
    <summary>Version {revision.profile_version} · {new Intl.DateTimeFormat('en-GB', { timeZone: 'Africa/Addis_Ababa', dateStyle: 'medium', timeStyle: 'short' }).format(new Date(revision.recorded_at))} EAT</summary>
    <h3>{revision.name}</h3><p>{revision.services}</p><p>{revision.regions}</p>
   </details>) : <p>No profile revisions are available.</p>}
  </section>
 </>;
}
