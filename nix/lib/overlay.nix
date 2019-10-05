{ config }: self: super: {
  ci = super.ci.extend (cself: csuper: {
    inherit config;
  });
}
