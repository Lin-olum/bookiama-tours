import type { ReactNode } from "react";
const destinations = [
  {
    number: "01",
    name: "Kenya",
    description: "Where wild landscapes meet extraordinary experiences.",
    tag: "Our home",
    image:
      "https://images.unsplash.com/photo-1516426122078-c23e76319801?auto=format&fit=crop&w=1400&q=85",
    href: "/destinations/kenya",
  },
  {
    number: "02",
    name: "Tanzania",
    description: "Discover the magic of East Africa beyond borders.",
    tag: "Explore beyond",
    image:
      "https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?auto=format&fit=crop&w=1400&q=85",
    href: "/destinations/tanzania",
  },
];

const experiences = [
  {
    category: "WILDLIFE & SAFARI",
    name: "The African Wilderness",
    description: "Come closer to the landscapes and wildlife that make Africa unforgettable.",
    image:
      "https://images.unsplash.com/photo-1516426122078-c23e76319801?auto=format&fit=crop&w=1200&q=85",
    duration: "Explore safari experiences",
  },
  {
    category: "COASTAL ESCAPES",
    name: "The Art of Slowing Down",
    description: "Trade the everyday for warm coastlines, ocean air and beautiful moments.",
    image:
      "https://images.unsplash.com/photo-1514282401047-d79a71a590e8?auto=format&fit=crop&w=1200&q=85",
    duration: "Explore coastal experiences",
  },
  {
    category: "CULTURE & DISCOVERY",
    name: "Beyond the Ordinary",
    description: "Experience the people, stories and places that give every journey meaning.",
    image:
      "https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?auto=format&fit=crop&w=1200&q=85",
    duration: "Explore cultural experiences",
  },
];

const collections = [
  {
    number: "01",
    name: "Bokiama Wild",
    description: "For the ones who feel most alive in the wilderness.",
  },
  {
    number: "02",
    name: "Bokiama Escape",
    description: "A little distance from the ordinary. A little closer to yourself.",
  },
  {
    number: "03",
    name: "Bokiama Together",
    description: "Meaningful journeys are even better when shared.",
  },
  {
    number: "04",
    name: "Bokiama Beyond",
    description: "For curious minds and journeys without boundaries.",
  },
  {
    number: "05",
    name: "Bokiama Hidden Gems",
    description: "The remarkable places that deserve to be discovered.",
  },
];

function SectionLabel({ children }: { children: React.ReactNode }) {
  return <p className="section-label">{children}</p>;
}

export default function Home() {
  const currentYear = 2026;
  return (
    <main>
      <header className="site-header">
        <a href="/" className="brand" aria-label="Bokiama Tours and Travel home">
          <span className="brand-symbol">B</span>
          <span className="brand-name">
            BOKIAMA
            <small>TOURS &amp; TRAVEL</small>
          </span>
        </a>

        <nav className="desktop-nav" aria-label="Main navigation">
          <a href="/">Home</a>
          <a href="/destinations/kenya">Destinations</a>
          <a href="/tours">Our Tours</a>
          <a href="/collections">Experiences</a>
          <a href="/about">Our Story</a>
        </nav>

        <a href="/contact" className="header-cta">
          Plan your journey <span>↗</span>
        </a>

        <details className="mobile-menu">
          <summary aria-label="Open navigation menu">☰</summary>
          <nav aria-label="Mobile navigation">
            <a href="/">Home</a>
            <a href="/destinations/kenya">Kenya</a>
            <a href="/destinations/tanzania">Tanzania</a>
            <a href="/tours">Our Tours</a>
            <a href="/collections">Experiences</a>
            <a href="/about">Our Story</a>
            <a href="/contact">Contact</a>
          </nav>
        </details>
      </header>

      <section className="hero">
        <div className="hero-image" />
        <div className="hero-overlay" />

        <div className="hero-content">
          <p className="hero-eyebrow">
            <span /> YOUR JOURNEY. YOUR AFRICA.
          </p>

          <h1>
            The world is
            <br />
            waiting <em>out there.</em>
          </h1>

          <p className="hero-description">
            Extraordinary journeys begin with a little curiosity.
            Discover the landscapes, cultures and experiences
            that make East Africa unforgettable.
          </p>

          <div className="hero-actions">
            <a href="/tours" className="button button-gold">
              Explore our journeys <span>↗</span>
            </a>
            <a href="#destinations" className="text-link">
              Discover Bokiama <span>↓</span>
            </a>
          </div>
        </div>

        <div className="hero-bottom">
          <span>KENYA · TANZANIA · BEYOND</span>
          <span>01 / DISCOVER EAST AFRICA</span>
        </div>
      </section>

      <section className="intro section-padding">
        <div>
          <SectionLabel>THE BOKIAMA EXPERIENCE</SectionLabel>
          <h2>
            Not just places.
            <br />
            <em>Stories worth living.</em>
          </h2>
        </div>

        <div className="intro-copy">
          <p>
            We believe travel is about more than arriving somewhere.
            It is about the people you meet, the places that stay with
            you and the moments that become part of your story.
          </p>
          <a href="/about" className="underlined-link">
            Get to know us <span>↗</span>
          </a>
        </div>
      </section>

      <section id="destinations" className="destinations section-padding">
        <div className="section-heading">
          <div>
            <SectionLabel>WHERE WILL WE TAKE YOU?</SectionLabel>
            <h2>Find your <em>somewhere.</em></h2>
          </div>
          <p>
            From the heart of Kenya to the remarkable landscapes
            of Tanzania, your next story starts here.
          </p>
        </div>

        <div className="destination-grid">
          {destinations.map((destination) => (
            <a
              href={destination.href}
              key={destination.name}
              className="destination-card"
              style={{
                backgroundImage: `linear-gradient(0deg, rgba(9,24,25,.8), transparent 70%), url("${destination.image}")`,
              }}
            >
              <span className="destination-number">{destination.number}</span>
              <span className="destination-tag">{destination.tag}</span>
              <div className="destination-info">
                <h3>{destination.name}</h3>
                <p>{destination.description}</p>
                <span className="destination-link">
                  Explore destination <span>↗</span>
                </span>
              </div>
            </a>
          ))}
        </div>
      </section>

      <section className="experiences section-padding">
        <div className="section-heading">
          <div>
            <SectionLabel>CURATED FOR THE CURIOUS</SectionLabel>
            <h2>Experiences that <em>stay.</em></h2>
          </div>
          <a href="/tours" className="underlined-link">
            Explore all journeys <span>↗</span>
          </a>
        </div>

        <div className="experience-grid">
          {experiences.map((experience) => (
            <article className="experience-card" key={experience.name}>
              <a href="/tours" className="experience-image">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={experience.image} alt={experience.name} />
                <span className="image-arrow">↗</span>
              </a>
              <div className="experience-content">
                <SectionLabel>{experience.category}</SectionLabel>
                <h3>{experience.name}</h3>
                <p>{experience.description}</p>
                <a href="/tours" className="experience-link">
                  {experience.duration} ↗
                </a>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="collections section-padding">
        <div className="collection-heading">
          <SectionLabel>THE BOKIAMA COLLECTIONS</SectionLabel>
          <h2>
            There is a journey
            <br />
            <em>for every kind of you.</em>
          </h2>
          <p>
            However you love to travel, there is a Bokiama experience
            waiting to be discovered.
          </p>
        </div>

        <div className="collection-list">
          {collections.map((collection) => (
            <a
              href="/collections"
              className="collection-item"
              key={collection.name}
            >
              <span className="collection-number">{collection.number}</span>
              <h3>{collection.name}</h3>
              <p>{collection.description}</p>
              <span className="collection-arrow">↗</span>
            </a>
          ))}
        </div>
      </section>

      <section className="custom-trip">
        <div className="custom-trip-content">
          <SectionLabel>YOUR JOURNEY, YOUR WAY</SectionLabel>
          <h2>
            Have somewhere
            <br />
            <em>in mind?</em>
          </h2>
          <p>
            Tell us what you are dreaming of. We will help you
            put together a journey that makes sense for you.
          </p>
          <a href="/contact" className="button button-gold">
            Let's plan something <span>↗</span>
          </a>
        </div>
      </section>

      <footer className="site-footer">
        <div className="footer-top">
          <a href="/" className="brand footer-brand">
            <span className="brand-symbol">B</span>
            <span className="brand-name">
              BOKIAMA
              <small>TOURS &amp; TRAVEL</small>
            </span>
          </a>
          <p>
            Go beyond the expected.
            <br />
            Come back with a story.
          </p>
        </div>

        <div className="footer-links">
          <div>
            <span>EXPLORE</span>
            <a href="/destinations/kenya">Kenya</a>
            <a href="/destinations/tanzania">Tanzania</a>
            <a href="/tours">Our tours</a>
          </div>
          <div>
            <span>DISCOVER</span>
            <a href="/collections">Collections</a>
            <a href="/about">Our story</a>
            <a href="/contact">Contact us</a>
          </div>
          <div>
            <span>GET IN TOUCH</span>
            <a href="/contact">Plan a journey</a>
            <a href="/contact">Make an enquiry</a>
          </div>
        </div>

        <div className="footer-bottom">
          <span>© {currentYear} Bokiama Tours &amp; Travel.</span>
          <span>MADE FOR THE LOVE OF THE JOURNEY.</span>
        </div>
      </footer>
    </main>
  );
}
