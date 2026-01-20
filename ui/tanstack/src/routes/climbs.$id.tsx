import { createFileRoute, Link } from '@tanstack/react-router'
import { fetchClimb } from '@/db'

export const Route = createFileRoute('/climbs/$id')({
  component: ClimbDetailPage,
  loader: async ({ params }) => {
    const climb = await fetchClimb(params.id)
    if (!climb) {
      throw new Error('Climb not found')
    }
    return { climb }
  },
})

function ClimbDetailPage() {
  const { climb } = Route.useLoaderData()
  const pathTokens = climb.areas?.path_tokens || []

  return (
    <div className="px-4 py-8 max-w-3xl mx-auto">
      {/* Breadcrumb */}
      {pathTokens.length > 0 && (
        <nav className="text-sm mb-6 border border-neutral-200 rounded-lg overflow-hidden">
          <table className="w-full">
            <tbody>
              <tr className="border-b border-neutral-200 hover:bg-neutral-50">
                <td className="py-2 px-4">
                  <Link to="/areas" className="text-neutral-600 hover:text-neutral-900">
                    ← {pathTokens.join(' › ')}
                  </Link>
                </td>
              </tr>
              <tr className="bg-neutral-50">
                <td className="py-2 px-4 font-medium">{climb.name}</td>
              </tr>
            </tbody>
          </table>
        </nav>
      )}

      <h1 className="mb-2">{climb.name}</h1>

      {/* Location context */}
      {climb.areas && (
        <p className="text-neutral-500 mb-6">{climb.areas.name}</p>
      )}

      {/* Grades */}
      <div className="flex gap-4 mb-6 text-lg">
        {climb.grade_yds && <span>{climb.grade_yds}</span>}
        {climb.grade_vscale && <span>{climb.grade_vscale}</span>}
        {climb.grade_french && <span>{climb.grade_french}</span>}
      </div>

      {/* Type badges */}
      <div className="flex gap-2 mb-8">
        {climb.is_sport && <span className="px-3 py-1 rounded bg-emerald-100 text-emerald-700 text-sm">Sport</span>}
        {climb.is_trad && <span className="px-3 py-1 rounded bg-amber-100 text-amber-700 text-sm">Trad</span>}
        {climb.is_boulder && <span className="px-3 py-1 rounded bg-violet-100 text-violet-700 text-sm">Boulder</span>}
        {climb.is_alpine && <span className="px-3 py-1 rounded bg-sky-100 text-sky-700 text-sm">Alpine</span>}
      </div>

      {/* Details */}
      <div className="border-t border-neutral-200 py-6 space-y-4">
        {climb.fa && (
          <div className="flex">
            <span className="text-neutral-500 w-32">First Ascent</span>
            <span>{climb.fa}</span>
          </div>
        )}

        {climb.length_meters && climb.length_meters > 0 && (
          <div className="flex">
            <span className="text-neutral-500 w-32">Length</span>
            <span>{climb.length_meters}m</span>
          </div>
        )}

        {climb.bolts_count && climb.bolts_count > 0 && (
          <div className="flex">
            <span className="text-neutral-500 w-32">Bolts</span>
            <span>{climb.bolts_count}</span>
          </div>
        )}

        {climb.safety && climb.safety !== 'UNSPECIFIED' && (
          <div className="flex">
            <span className="text-neutral-500 w-32">Safety</span>
            <span>{climb.safety}</span>
          </div>
        )}

        {climb.lat && climb.lng && (
          <div className="flex">
            <span className="text-neutral-500 w-32">Coordinates</span>
            <span>{climb.lat.toFixed(5)}, {climb.lng.toFixed(5)}</span>
          </div>
        )}
      </div>

      {/* Description */}
      {climb.description && (
        <div className="border-t border-neutral-200 py-6">
          <h2 className="mb-4">Description</h2>
          <p className="text-neutral-700 whitespace-pre-wrap leading-relaxed">{climb.description}</p>
        </div>
      )}
    </div>
  )
}
