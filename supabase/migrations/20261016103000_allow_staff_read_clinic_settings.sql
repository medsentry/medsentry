DROP POLICY IF EXISTS system_settings_access ON public.system_settings;

CREATE POLICY system_settings_read ON public.system_settings
  FOR SELECT TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (
      public.medsentry_current_role() IN ('admin', 'staff') AND
      clinic_id = public.medsentry_current_clinic_id()
    )
  );

CREATE POLICY system_settings_manage ON public.system_settings
  FOR ALL TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (
      public.medsentry_current_role() = 'admin' AND
      (clinic_id IS NULL OR clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (
      public.medsentry_current_role() = 'admin' AND
      clinic_id = public.medsentry_current_clinic_id()
    )
  );
