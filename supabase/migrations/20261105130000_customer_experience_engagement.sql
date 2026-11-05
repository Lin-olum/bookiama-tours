
-- ============================================================================
-- BOKIAMA TOURS & TRAVEL
-- MIGRATION 003: CUSTOMER EXPERIENCE AND ENGAGEMENT
-- Date: 2026-11-05
--
-- Prerequisites:
--   Migration 001: Initial database
--   Migration 002: Business model expansion
--
-- Adds:
--   1. Customer travel preferences
--   2. Saved tours
--   3. Customer reviews
--   4. Bokiama Travel Stories
--   5. Private booking documents
--   6. Explorer Club loyalty accounts
--   7. Loyalty points ledger
--   8. Tour partners
--   9. Tour-partner relationships
--
-- Security:
--   Customer records are restricted to their owners.
--   Public reviews/stories require moderation.
--   Public stories additionally require publication consent.
--   Administrative access uses public.is_bokiama_owner().
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. CUSTOMER TRAVEL PREFERENCES
-- ---------------------------------------------------------------------------

CREATE TABLE public.customer_preferences (
    customer_id uuid PRIMARY KEY
        REFERENCES auth.users(id) ON DELETE CASCADE,

    preferred_currency text
        CHECK (preferred_currency IS NULL OR preferred_currency ~ '^[A-Z]{3}$'),

    preferred_language text NOT NULL DEFAULT 'en',

    preferred_travel_styles text[] NOT NULL DEFAULT '{}',

    preferred_destinations uuid[] NOT NULL DEFAULT '{}',

    interests text[] NOT NULL DEFAULT '{}',

    preferred_accommodation text,

    preferred_communication text
        CHECK (
            preferred_communication IS NULL
            OR preferred_communication IN ('email', 'phone', 'whatsapp')
        ),

    marketing_consent boolean NOT NULL DEFAULT false,
    marketing_consent_at timestamptz,

    personalization_consent boolean NOT NULL DEFAULT false,
    personalization_consent_at timestamptz,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX customer_preferences_currency_idx
    ON public.customer_preferences(preferred_currency);


-- ---------------------------------------------------------------------------
-- 2. SAVED TOURS
-- ---------------------------------------------------------------------------

CREATE TABLE public.saved_tours (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id uuid NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    tour_id uuid NOT NULL
        REFERENCES public.tours(id) ON DELETE CASCADE,

    created_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (customer_id, tour_id)
);

CREATE INDEX saved_tours_customer_idx
    ON public.saved_tours(customer_id, created_at DESC);

CREATE INDEX saved_tours_tour_idx
    ON public.saved_tours(tour_id);


-- ---------------------------------------------------------------------------
-- 3. CUSTOMER REVIEWS
-- ---------------------------------------------------------------------------

CREATE TABLE public.customer_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id uuid NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    booking_id uuid NOT NULL
        REFERENCES public.booking_requests(id) ON DELETE RESTRICT,

    tour_id uuid NOT NULL
        REFERENCES public.tours(id) ON DELETE RESTRICT,

    rating integer NOT NULL
        CHECK (rating BETWEEN 1 AND 5),

    title text,
    review_text text NOT NULL
        CHECK (length(trim(review_text)) >= 10),

    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),

    is_verified_booking boolean NOT NULL DEFAULT false,

    admin_response text,
    moderated_at timestamptz,
    moderated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (customer_id, booking_id)
);

CREATE INDEX customer_reviews_tour_status_idx
    ON public.customer_reviews(tour_id, status, created_at DESC);

CREATE INDEX customer_reviews_customer_idx
    ON public.customer_reviews(customer_id);


-- ---------------------------------------------------------------------------
-- 4. BOKIAMA TRAVEL STORIES
-- ---------------------------------------------------------------------------

CREATE TABLE public.travel_stories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id uuid
        REFERENCES auth.users(id) ON DELETE SET NULL,

    booking_id uuid
        REFERENCES public.booking_requests(id) ON DELETE SET NULL,

    tour_id uuid
        REFERENCES public.tours(id) ON DELETE SET NULL,

    display_name text NOT NULL,

    title text NOT NULL,
    story_text text NOT NULL
        CHECK (length(trim(story_text)) >= 10),

    media_storage_path text,

    -- Publication is prohibited unless the customer explicitly consents.
    publication_consent boolean NOT NULL DEFAULT false,
    consent_given_at timestamptz,

    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'hidden')),

    featured boolean NOT NULL DEFAULT false,

    moderated_at timestamptz,
    moderated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT travel_story_consent_check CHECK (
        (publication_consent = false AND consent_given_at IS NULL)
        OR
        (publication_consent = true AND consent_given_at IS NOT NULL)
    )
);

CREATE INDEX travel_stories_public_idx
    ON public.travel_stories(status, publication_consent, created_at DESC);

CREATE INDEX travel_stories_tour_idx
    ON public.travel_stories(tour_id);


-- ---------------------------------------------------------------------------
-- 5. PRIVATE BOOKING DOCUMENTS
-- ---------------------------------------------------------------------------

CREATE TABLE public.booking_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    booking_id uuid NOT NULL
        REFERENCES public.booking_requests(id) ON DELETE CASCADE,

    customer_id uuid NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    document_type text NOT NULL
        CHECK (
            document_type IN (
                'itinerary',
                'booking_confirmation',
                'travel_checklist',
                'voucher',
                'invoice',
                'other'
            )
        ),

    document_name text NOT NULL,

    storage_path text NOT NULL UNIQUE,

    description text,

    uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX booking_documents_customer_idx
    ON public.booking_documents(customer_id, created_at DESC);

CREATE INDEX booking_documents_booking_idx
    ON public.booking_documents(booking_id);


-- ---------------------------------------------------------------------------
-- 6. BOKIAMA EXPLORER CLUB ACCOUNTS
-- ---------------------------------------------------------------------------

CREATE TABLE public.explorer_club_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id uuid NOT NULL UNIQUE
        REFERENCES auth.users(id) ON DELETE CASCADE,

    membership_level text NOT NULL DEFAULT 'explorer'
        CHECK (
            membership_level IN (
                'explorer',
                'adventurer',
                'world_traveller'
            )
        ),

    points_balance integer NOT NULL DEFAULT 0
        CHECK (points_balance >= 0),

    lifetime_points_earned integer NOT NULL DEFAULT 0
        CHECK (lifetime_points_earned >= 0),

    joined_at timestamptz NOT NULL DEFAULT now(),

    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'closed')),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX explorer_club_level_idx
    ON public.explorer_club_accounts(membership_level);


-- ---------------------------------------------------------------------------
-- 7. EXPLORER CLUB POINTS LEDGER
-- ---------------------------------------------------------------------------

CREATE TABLE public.explorer_club_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    account_id uuid NOT NULL
        REFERENCES public.explorer_club_accounts(id) ON DELETE RESTRICT,

    transaction_type text NOT NULL
        CHECK (
            transaction_type IN (
                'booking_earned',
                'referral_earned',
                'reward_redeemed',
                'admin_adjustment',
                'points_expired'
            )
        ),

    points_change integer NOT NULL
        CHECK (points_change <> 0),

    description text NOT NULL,

    booking_id uuid
        REFERENCES public.booking_requests(id) ON DELETE SET NULL,

    reference_code text UNIQUE,

    created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX explorer_transactions_account_idx
    ON public.explorer_club_transactions(account_id, created_at DESC);

CREATE INDEX explorer_transactions_booking_idx
    ON public.explorer_club_transactions(booking_id);


-- ---------------------------------------------------------------------------
-- 8. TOUR PARTNERS
-- ---------------------------------------------------------------------------

CREATE TABLE public.tour_partners (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    business_name text NOT NULL,

    partner_type text NOT NULL
        CHECK (
            partner_type IN (
                'accommodation',
                'transport',
                'tour_operator',
                'activity_provider',
                'guide',
                'restaurant',
                'other'
            )
        ),

    country_code text
        CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),

    contact_person text,
    contact_email text,
    contact_phone text,

    website_url text,

    description text,

    verification_status text NOT NULL DEFAULT 'pending'
        CHECK (
            verification_status IN (
                'pending',
                'verified',
                'rejected',
                'suspended'
            )
        ),

    is_active boolean NOT NULL DEFAULT true,

    admin_notes text,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX tour_partners_type_idx
    ON public.tour_partners(partner_type, verification_status);


-- ---------------------------------------------------------------------------
-- 9. TOUR-PARTNER RELATIONSHIPS
-- ---------------------------------------------------------------------------

CREATE TABLE public.tour_partner_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    tour_id uuid NOT NULL
        REFERENCES public.tours(id) ON DELETE CASCADE,

    partner_id uuid NOT NULL
        REFERENCES public.tour_partners(id) ON DELETE RESTRICT,

    service_description text,

    is_primary_partner boolean NOT NULL DEFAULT false,

    created_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (tour_id, partner_id)
);

CREATE INDEX tour_partner_assignments_tour_idx
    ON public.tour_partner_assignments(tour_id);

CREATE INDEX tour_partner_assignments_partner_idx
    ON public.tour_partner_assignments(partner_id);


-- ---------------------------------------------------------------------------
-- 10. ENABLE ROW LEVEL SECURITY
-- ---------------------------------------------------------------------------

ALTER TABLE public.customer_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_tours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.travel_stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.explorer_club_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.explorer_club_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tour_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tour_partner_assignments ENABLE ROW LEVEL SECURITY;


-- ---------------------------------------------------------------------------
-- 11. CUSTOMER PREFERENCES POLICIES
-- ---------------------------------------------------------------------------

CREATE POLICY "Customers read own preferences"
ON public.customer_preferences
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()));

CREATE POLICY "Customers create own preferences"
ON public.customer_preferences
FOR INSERT TO authenticated
WITH CHECK (customer_id = (SELECT auth.uid()));

CREATE POLICY "Customers update own preferences"
ON public.customer_preferences
FOR UPDATE TO authenticated
USING (customer_id = (SELECT auth.uid()))
WITH CHECK (customer_id = (SELECT auth.uid()));

CREATE POLICY "Owner manages customer preferences"
ON public.customer_preferences
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 12. SAVED TOURS POLICIES
-- ---------------------------------------------------------------------------

CREATE POLICY "Customers read own saved tours"
ON public.saved_tours
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()));

CREATE POLICY "Customers save own tours"
ON public.saved_tours
FOR INSERT TO authenticated
WITH CHECK (customer_id = (SELECT auth.uid()));

CREATE POLICY "Customers remove own saved tours"
ON public.saved_tours
FOR DELETE TO authenticated
USING (customer_id = (SELECT auth.uid()));

CREATE POLICY "Owner manages saved tours"
ON public.saved_tours
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 13. CUSTOMER REVIEWS POLICIES
-- ---------------------------------------------------------------------------

-- Public visitors can only see approved reviews.
CREATE POLICY "Public read approved reviews"
ON public.customer_reviews
FOR SELECT TO anon, authenticated
USING (status = 'approved');

-- Customers can see their own reviews, including pending/rejected reviews.
CREATE POLICY "Customers read own reviews"
ON public.customer_reviews
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()));

-- Only customers with a completed booking for that tour can submit a review.
CREATE POLICY "Customers submit reviews for completed bookings"
ON public.customer_reviews
FOR INSERT TO authenticated
WITH CHECK (
    customer_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1
        FROM public.booking_requests b
        WHERE b.id = booking_id
          AND b.customer_id = (SELECT auth.uid())
          AND b.tour_id = tour_id
          AND b.status = 'completed'
    )
);

CREATE POLICY "Owner manages customer reviews"
ON public.customer_reviews
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 14. TRAVEL STORIES POLICIES
-- ---------------------------------------------------------------------------

-- Public stories require both approval and explicit publication consent.
CREATE POLICY "Public read approved consented stories"
ON public.travel_stories
FOR SELECT TO anon, authenticated
USING (
    status = 'approved'
    AND publication_consent = true
);

CREATE POLICY "Customers read own stories"
ON public.travel_stories
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()));

CREATE POLICY "Customers submit own stories"
ON public.travel_stories
FOR INSERT TO authenticated
WITH CHECK (
    customer_id = (SELECT auth.uid())
    AND (
        publication_consent = false
        OR consent_given_at IS NOT NULL
    )
);

CREATE POLICY "Owner manages travel stories"
ON public.travel_stories
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 15. BOOKING DOCUMENT POLICIES
-- ---------------------------------------------------------------------------

CREATE POLICY "Customers read own booking documents"
ON public.booking_documents
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()));

CREATE POLICY "Owner manages booking documents"
ON public.booking_documents
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 16. EXPLORER CLUB ACCOUNT POLICIES
-- ---------------------------------------------------------------------------

CREATE POLICY "Customers read own Explorer Club account"
ON public.explorer_club_accounts
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()));

CREATE POLICY "Owner manages Explorer Club accounts"
ON public.explorer_club_accounts
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 17. EXPLORER CLUB TRANSACTION POLICIES
-- ---------------------------------------------------------------------------

CREATE POLICY "Customers read own loyalty transactions"
ON public.explorer_club_transactions
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.explorer_club_accounts a
        WHERE a.id = account_id
          AND a.customer_id = (SELECT auth.uid())
    )
);

CREATE POLICY "Owner manages loyalty transactions"
ON public.explorer_club_transactions
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 18. PARTNER MANAGEMENT POLICIES
-- ---------------------------------------------------------------------------

CREATE POLICY "Owner manages tour partners"
ON public.tour_partners
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());

CREATE POLICY "Owner manages tour partner assignments"
ON public.tour_partner_assignments
FOR ALL TO authenticated
USING (public.is_bokiama_owner())
WITH CHECK (public.is_bokiama_owner());


-- ---------------------------------------------------------------------------
-- 19. TABLE PERMISSIONS
-- RLS policies remain responsible for deciding which rows are accessible.
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.customer_preferences,
   public.saved_tours,
   public.customer_reviews,
   public.travel_stories,
   public.booking_documents,
   public.explorer_club_accounts,
   public.explorer_club_transactions,
   public.tour_partners,
   public.tour_partner_assignments
TO authenticated;

GRANT SELECT
ON public.customer_reviews,
   public.travel_stories
TO anon;


COMMIT;

-- ============================================================================
-- END MIGRATION 003
-- ============================================================================
