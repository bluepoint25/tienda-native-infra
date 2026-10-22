const SCOPES_POR_GRUPO = {
  lectores: ["productos/read"],
  editores: ["productos/read", "productos/write"],
};

export const handler = async (event) => {
  const grupos = event.request.groupConfiguration?.groupsToOverride ?? [];
  const scopes = [...new Set(grupos.flatMap((g) => SCOPES_POR_GRUPO[g] ?? []))];

  console.log(JSON.stringify({ usuario: event.userName, grupos, scopes }));

  event.response = {
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: { scopesToAdd: scopes },
    },
  };
  return event;
};
