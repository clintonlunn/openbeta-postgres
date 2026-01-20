import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://hswfsehtiwaqcfndygvr.supabase.co'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Helper for typed queries
export async function fetchAreas(params?: {
  parentId?: string | null
  limit?: number
}) {
  let query = supabase
    .from('areas')
    .select('id, name, path_tokens, total_climbs, is_leaf, lat, lng')

  if (params?.parentId === null) {
    query = query.is('parent_id', null)
  } else if (params?.parentId) {
    query = query.eq('parent_id', params.parentId)
  }

  query = query.order('total_climbs', { ascending: false })

  if (params?.limit) {
    query = query.limit(params.limit)
  }

  const { data, error } = await query
  if (error) throw error
  return data
}

export async function fetchAreaByPath(pathTokens: string[]) {
  const { data, error } = await supabase
    .from('areas')
    .select('id, name, path_tokens, total_climbs, is_leaf, lat, lng, parent_id')
    .contains('path_tokens', pathTokens)
    .eq('path_tokens', pathTokens)
    .single()

  if (error) throw error
  return data
}

export async function fetchClimbsByArea(areaId: string, limit = 100) {
  const { data, error } = await supabase
    .from('climbs')
    .select('id, name, grade_yds, grade_vscale, is_sport, is_trad, is_boulder, fa')
    .eq('area_id', areaId)
    .order('name')
    .limit(limit)

  if (error) throw error
  return data
}

export async function fetchClimb(id: string) {
  const { data, error } = await supabase
    .from('climbs')
    .select('*, areas(name, path_tokens)')
    .eq('id', id)
    .single()

  if (error) throw error
  return data
}

export async function fetchClimbs(limit = 100) {
  const { data, error } = await supabase
    .from('climbs')
    .select('id, name, grade_yds, grade_vscale, is_sport, is_trad, is_boulder, areas(name, path_tokens)')
    .order('name')
    .limit(limit)

  if (error) throw error
  return data
}
