import { createFileRoute, Link } from '@tanstack/react-router'
import { supabase, fetchClimbsByArea } from '@/db'

export const Route = createFileRoute('/areas/$areaId')({
  component: AreaPage,
  loader: async ({ params }) => {
    // Fetch this area
    const { data: area, error: areaError } = await supabase
      .from('areas')
      .select('id, name, path_tokens, total_climbs, is_leaf, parent_id')
      .eq('id', params.areaId)
      .single()

    if (areaError) throw areaError

    // Fetch child areas
    const { data: children, error: childError } = await supabase
      .from('areas')
      .select('id, name, total_climbs, is_leaf')
      .eq('parent_id', params.areaId)
      .order('total_climbs', { ascending: false })

    if (childError) throw childError

    // If leaf area, fetch climbs
    let climbs: any[] = []
    if (area.is_leaf) {
      climbs = await fetchClimbsByArea(params.areaId, 200)
    }

    return { area, children, climbs }
  },
})

function AreaPage() {
  const { area, children, climbs } = Route.useLoaderData()
  const pathTokens = area.path_tokens || []

  return (
    <div className="px-4 py-8 max-w-5xl mx-auto">
      {/* Breadcrumb */}
      <nav className="text-sm mb-6 border border-neutral-200 rounded-lg overflow-hidden">
        <table className="w-full">
          <tbody>
            <tr className="border-b border-neutral-200 hover:bg-neutral-50">
              <td className="py-2 px-4">
                {area.parent_id ? (
                  <Link
                    to="/areas/$areaId"
                    params={{ areaId: area.parent_id }}
                    className="text-neutral-600 hover:text-neutral-900"
                  >
                    ← Back
                  </Link>
                ) : (
                  <Link to="/areas" className="text-neutral-600 hover:text-neutral-900">
                    ← All Countries
                  </Link>
                )}
              </td>
            </tr>
            <tr className="bg-neutral-50">
              <td className="py-2 px-4 font-medium">
                {pathTokens.join(' › ')}
              </td>
            </tr>
          </tbody>
        </table>
      </nav>

      <h1 className="mb-2">{area.name}</h1>
      <p className="text-neutral-500 mb-6">{area.total_climbs?.toLocaleString()} climbs</p>

      {/* Child areas */}
      {children.length > 0 && (
        <div className="mb-8">
          <h2 className="mb-4">Sub-areas</h2>
          <div className="grid gap-0 border-t border-neutral-200">
            {children.map((child: any) => (
              <Link
                key={child.id}
                to="/areas/$areaId"
                params={{ areaId: child.id }}
                className="flex justify-between items-center py-3 px-4 border-b border-neutral-200 hover:bg-neutral-50 no-underline"
              >
                <span className="font-medium">{child.name}</span>
                <span className="text-neutral-500 text-sm">
                  {child.total_climbs?.toLocaleString()} climbs
                </span>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Climbs (if leaf area) */}
      {climbs.length > 0 && (
        <div>
          <h2 className="mb-4">Climbs</h2>
          <div className="grid gap-0 border-t border-neutral-200">
            {climbs.map((climb: any) => (
              <Link
                key={climb.id}
                to="/climbs/$id"
                params={{ id: climb.id }}
                className="flex justify-between items-center py-3 px-4 border-b border-neutral-200 hover:bg-neutral-50 no-underline"
              >
                <div className="font-medium">{climb.name}</div>
                <div className="flex gap-3 items-center text-sm">
                  {climb.grade_yds && <span className="text-neutral-600">{climb.grade_yds}</span>}
                  {climb.grade_vscale && <span className="text-neutral-600">{climb.grade_vscale}</span>}
                  {climb.is_sport && <span className="text-xs px-2 py-0.5 rounded bg-emerald-100 text-emerald-700">sport</span>}
                  {climb.is_trad && <span className="text-xs px-2 py-0.5 rounded bg-amber-100 text-amber-700">trad</span>}
                  {climb.is_boulder && <span className="text-xs px-2 py-0.5 rounded bg-violet-100 text-violet-700">boulder</span>}
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
