import { createFileRoute, Link } from '@tanstack/react-router'
import { fetchAreas } from '@/db'

export const Route = createFileRoute('/areas/')({
  component: AreasIndex,
  loader: async () => {
    // Fetch top-level areas (countries)
    const countries = await fetchAreas({ parentId: null })
    return { countries }
  },
})

function AreasIndex() {
  const { countries } = Route.useLoaderData()
  const totalClimbs = countries.reduce((sum, c) => sum + (c.total_climbs || 0), 0)

  return (
    <div className="px-4 py-8 max-w-5xl mx-auto">
      <nav className="text-sm mb-6 border border-neutral-200 rounded-lg overflow-hidden">
        <table className="w-full">
          <tbody>
            <tr className="bg-neutral-50">
              <td className="py-2 px-4 font-medium">Areas</td>
              <td className="py-2 px-4 text-right text-neutral-500">{countries.length} countries</td>
              <td className="py-2 px-4 text-right text-neutral-500">{totalClimbs.toLocaleString()} climbs</td>
            </tr>
          </tbody>
        </table>
      </nav>

      <h1 className="mb-6">Browse Areas</h1>

      <div className="grid gap-0 border-t border-neutral-200">
        {countries.map((c) => (
          <Link
            key={c.id}
            to="/areas/$areaId"
            params={{ areaId: c.id }}
            className="flex justify-between items-center py-4 px-4 border-b border-neutral-200 hover:bg-neutral-50 no-underline"
          >
            <span className="font-medium">{c.name}</span>
            <span className="text-neutral-500 text-sm">{(c.total_climbs || 0).toLocaleString()} climbs</span>
          </Link>
        ))}
      </div>
    </div>
  )
}
